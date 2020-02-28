#!/usr/bin/env python3

import socket
import sys

HOST = "0.0.0.0"
PORT = int(sys.argv[1])

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind((HOST, PORT))
    s.listen(1)

    conn, addr = s.accept()
    with conn:
        print('Connected by', addr)
        while True:
            data = conn.recv(1024)

            if not data:
            	break

            conn.sendall(data.decode().upper().encode())
