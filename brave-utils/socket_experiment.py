#!/usr/bin/env python
import fcntl
import logging
import os
import pathlib
import select
import socket
import sys

logger = logging.getLogger(__name__)

def main(in_pipe_path: pathlib.Path, out_pipe_path: pathlib.Path, sock_path: pathlib.Path) -> None:
    logger.debug(f"Making input pipe: {in_pipe_path}")
    if not os.path.exists(in_pipe_path):
        os.mkfifo(in_pipe_path)
    logger.debug(f"Making output pipe: {out_pipe_path}")
    if not os.path.exists(out_pipe_path):
        os.mkfifo(out_pipe_path)

    logger.debug("Opening pipes")
    with open(in_pipe_path, "wb", buffering=0) as in_pipe, open(out_pipe_path, "rb") as out_pipe:
        logger.debug("Pipes open, getting socket")
        op_fd = out_pipe.fileno()
        op_flags = fcntl.fcntl(op_fd, fcntl.F_GETFL)
        fcntl.fcntl(op_fd, fcntl.F_SETFL, op_flags | os.O_NONBLOCK)
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            logger.debug(f"bind socket {sock_path}")

            if os.path.exists(sock_path):
                os.unlink(sock_path)
            s.bind(str(sock_path))

            logger.debug("Listening on the socket")
            s.listen(16)

            while True:
                r_sock, r_addr = s.accept()
                logger.debug(f"got a bite from {r_addr}")
                msg = b""
                while True:
                    chunk = r_sock.recv(1024)
                    logger.debug(f"Got chunk: {chunk}")
                    nul_idx = chunk.find(b"\0")
                    if nul_idx == -1:
                        msg += chunk
                        continue
                    logger.debug(f"Null byte at {nul_idx}")
                    msg += chunk[:nul_idx+1]
                    break

                logger.debug(f"Got message: {msg}")
                logger.debug("Writing message to pipe")
                in_pipe.write(msg)

                response = b""
                logger.debug("Reading response from process")
                while True:
                    logger.debug(f"Selecting from {out_pipe.name}")
                    select.select([out_pipe], [], [])
                    logger.debug(f"Selected!")
                    out_chunk = out_pipe.read()
                    logger.debug(f"Got chunk: {out_chunk} with {len(out_chunk)} bytes")
                    nul_idx = out_chunk.find(b"\0")
                    if nul_idx == -1:
                        response += out_chunk
                        continue
                    logger.debug("Null byte found")
                    response += out_chunk[:nul_idx+1]
                    logger.debug(f"Got response: {response}")
                    break

                r_sock.sendall(response)
                r_sock.close()

if __name__ == "__main__":
    logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
    main(pathlib.Path("in.fifo"), pathlib.Path("out.fifo"), pathlib.Path("fifo.sock"))
