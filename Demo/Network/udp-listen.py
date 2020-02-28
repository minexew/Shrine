#!/usr/bin/env python3

import socket
import sys

HOST = "0.0.0.0"
PORT = int(sys.argv[1])

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((HOST, PORT))

while True:
    data, addr = sock.recvfrom(2048)
    print("received message:", data.decode())
