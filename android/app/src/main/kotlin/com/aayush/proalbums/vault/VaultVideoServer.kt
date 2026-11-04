package com.aayush.proalbums.vault

import android.content.ContentResolver
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.io.FileInputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.util.Arrays
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Plays hidden videos without ever writing them decrypted to disk: a tiny
 * HTTP server on 127.0.0.1 (this phone only), one random token per video.
 * The player asks for byte ranges (seeking); each range is decrypted from
 * the vault file as it is sent.
 *
 *  - Only reachable from this phone (bound to 127.0.0.1), and only with a
 *    token (128 random bits) that exists while the vault is open.
 *  - [stop] (the vault locks) closes the server and forgets every token.
 *  - No caching: "Cache-Control: no-store"; the player keeps nothing.
 */
class VaultVideoServer(
    private val resolver: ContentResolver,
    private val folder: VaultFolder,
    /** A copy of the vault key, or null when locked (caller wipes). */
    private val key: () -> ByteArray?,
) {
    private var server: ServerSocket? = null
    private val tokens = ConcurrentHashMap<String, Long>()
    private val connections = Executors.newCachedThreadPool()

    /** The address the player opens for hidden video [fileId]. */
    @Synchronized
    fun urlFor(fileId: Long): String {
        val socket = server ?: start()
        val token = VaultCrypto.randomBytes(16).joinToString("") { "%02x".format(it) }
        tokens[token] = fileId
        return "http://127.0.0.1:${socket.localPort}/v/$token"
    }

    /** Closes the server and forgets every token (vault locked). */
    @Synchronized
    fun stop() {
        tokens.clear()
        try {
            server?.close()
        } catch (error: Exception) {
            // Already closed.
        }
        server = null
    }

    private fun start(): ServerSocket {
        val socket = ServerSocket(0, 16, InetAddress.getByName("127.0.0.1"))
        server = socket
        Thread({ accept(socket) }, "vault-video").apply {
            isDaemon = true
            start()
        }
        return socket
    }

    private fun accept(socket: ServerSocket) {
        while (!socket.isClosed) {
            val client = try {
                socket.accept()
            } catch (error: Exception) {
                break
            }
            connections.execute { serve(client) }
        }
    }

    private fun serve(client: Socket) {
        client.use { socket ->
            socket.soTimeout = 15_000
            try {
                val request = readHead(socket.getInputStream()) ?: return
                val out = BufferedOutputStream(socket.getOutputStream(), 64 * 1024)
                respond(request, out)
                out.flush()
            } catch (error: SocketException) {
                // The player closed the connection (seek, pause, close): normal.
            } catch (error: Exception) {
                // Nothing to tell: the player sees the connection end.
            }
        }
    }

    private class Request(val method: String, val path: String, val range: String?)

    /** The request line and headers (small, ASCII); null if malformed. */
    private fun readHead(input: InputStream): Request? {
        val bytes = StringBuilder()
        var last4 = 0
        while (bytes.length < 8192) {
            val read = input.read()
            if (read < 0) return null
            bytes.append(read.toChar())
            last4 = (last4 shl 8) or read
            if (last4 == 0x0D0A0D0A) break
        }
        val lines = bytes.split("\r\n")
        val parts = lines.firstOrNull()?.split(' ') ?: return null
        if (parts.size < 2) return null
        val range = lines.drop(1).firstOrNull { it.startsWith("Range:", ignoreCase = true) }
            ?.substringAfter(':')?.trim()
        return Request(parts[0], parts[1], range)
    }

    private fun respond(request: Request, out: OutputStream) {
        if (request.method != "GET" && request.method != "HEAD") {
            status(out, "405 Method Not Allowed")
            return
        }
        val token = request.path.removePrefix("/v/")
        val fileId = tokens[token]
        if (!request.path.startsWith("/v/") || fileId == null) {
            status(out, "404 Not Found")
            return
        }
        val dek = key() ?: run {
            status(out, "403 Forbidden")
            return
        }
        try {
            resolver.openFileDescriptor(folder.uriOf(fileId), "r")!!.use { descriptor ->
                FileInputStream(descriptor.fileDescriptor).channel.use { channel ->
                    VaultItemReader(FileChannelVaultSource(channel), dek).use { reader ->
                        send(request, reader, out)
                    }
                }
            }
        } finally {
            VaultCrypto.wipe(dek)
        }
    }

    private fun send(request: Request, reader: VaultItemReader, out: OutputStream) {
        val size = reader.plainSize
        val mime = JSONObject(String(reader.header())).optString(VaultHeader.MIME)
            .ifEmpty { "video/mp4" }
        val range = request.range?.let { parseRange(it, size) }
        if (request.range != null && range == null) {
            head(out, "416 Range Not Satisfiable", listOf("Content-Range: bytes */$size"))
            return
        }
        val (start, end) = range ?: (0L to size - 1)
        val length = if (size == 0L) 0L else end - start + 1
        head(
            out,
            if (range != null) "206 Partial Content" else "200 OK",
            listOfNotNull(
                "Content-Type: $mime",
                "Content-Length: $length",
                "Accept-Ranges: bytes",
                "Cache-Control: no-store",
                if (range != null) "Content-Range: bytes $start-$end/$size" else null,
            ),
        )
        if (request.method == "HEAD" || length == 0L) return

        // Chunk by chunk (each vault chunk is decrypted once).
        var at = start
        while (at <= end) {
            val inChunk = VaultItemFormat.CHUNK_BYTES - (at % VaultItemFormat.CHUNK_BYTES)
            val count = minOf(inChunk, end - at + 1).toInt()
            val plain = reader.read(at, count)
            out.write(plain)
            Arrays.fill(plain, 0)
            at += count
        }
    }

    /** "bytes=a-b", "bytes=a-", "bytes=-n" → (start, end) inside [size]. */
    private fun parseRange(header: String, size: Long): Pair<Long, Long>? {
        if (!header.startsWith("bytes=") || size <= 0) return null
        val spec = header.removePrefix("bytes=").substringBefore(',').trim()
        val dash = spec.indexOf('-')
        if (dash < 0) return null
        val first = spec.substring(0, dash).trim()
        val last = spec.substring(dash + 1).trim()
        val (start, end) = when {
            first.isEmpty() -> {
                val suffix = last.toLongOrNull() ?: return null
                (size - suffix).coerceAtLeast(0) to size - 1
            }
            else -> {
                val from = first.toLongOrNull() ?: return null
                val to = last.toLongOrNull()?.coerceAtMost(size - 1) ?: (size - 1)
                from to to
            }
        }
        return if (start in 0..end && end < size) start to end else null
    }

    private fun status(out: OutputStream, status: String) =
        head(out, status, listOf("Content-Length: 0"))

    private fun head(out: OutputStream, status: String, headers: List<String>) {
        val text = buildString {
            append("HTTP/1.1 ").append(status).append("\r\n")
            headers.forEach { append(it).append("\r\n") }
            append("Connection: close\r\n\r\n")
        }
        out.write(text.toByteArray(Charsets.ISO_8859_1))
    }
}
