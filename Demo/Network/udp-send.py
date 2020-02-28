#!/usr/bin/env python3

import socket
import sys

HOST = sys.argv[1]
PORT = int(sys.argv[2])
MESSAGE = sys.argv[3]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(MESSAGE.encode(), (HOST, PORT))
