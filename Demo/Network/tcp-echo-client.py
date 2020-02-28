#!/usr/bin/env python3

import socket
import sys

HOST = sys.argv[1]
PORT = int(sys.argv[2])
MESSAGE = sys.argv[3]

with socket.create_connection((HOST, PORT)) as s:
    s.sendall(MESSAGE.encode())
    data = s.recv(1024)

    if data:
        print('Received', data.decode())
