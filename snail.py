#!/usr/bin/env python

from __future__ import print_function

import socket
import struct
import sys
import time

TCP_IP = '127.0.0.1'
TCP_PORT = 7777

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect((TCP_IP, TCP_PORT))

# socket #0 is never used
socks = [False]

CMD_SOCKET = 1
CMD_CLOSE = 2
CMD_CONNECT_TCP = 3
CMD_SEND = 4
CMD_RECV = 5
CMD_HELLO = 0xAA

def recvall(sock, count):
    s = b''

    while len(s) < count:
        part = sock.recv(count - len(s))
        if part is None: break
        s += part

    return s

while True:
    cmd = ord(sock.recv(1))
    #print('%02X' % cmd)
    if cmd is None: break

    if cmd == CMD_HELLO:
        print('hello!')
        sock.send(b'\xAA')
    elif cmd == CMD_CLOSE:
        sockfd = ord(sock.recv(1))
        print('close(%d)' % (sockfd))

        socks[sockfd].close()
        socks[sockfd] = None
        sock.send(struct.pack('B', 0))
    elif cmd == CMD_CONNECT_TCP:
        sockfd, length = struct.unpack('BB', recvall(sock, 2))
        hostname = recvall(sock, length).decode()
        port, = struct.unpack('H', recvall(sock, 2))
        print('connectTcp(%d, %s, %d)' % (sockfd, hostname, port))

        try:
            socks[sockfd].connect((hostname, port))
            rc = 0
        except socket.error as e:
            print(e)
            rc = 0xff

        sock.send(struct.pack('B', rc))
    elif cmd == CMD_RECV:
        sockfd, length, flags = struct.unpack('BBB', recvall(sock, 3))
        #print('recv(%d, %d, %d)' % (sockfd, length, flags))

        try:
            data = socks[sockfd].recv(length)
        except socket.error as e:
            print(e)
            data = b''

        sock.send(struct.pack('B', len(data)))
        sock.send(data)
    elif cmd == CMD_SEND:
        sockfd, length, flags = struct.unpack('BBB', recvall(sock, 3))
        data = recvall(sock, length)
        #print('send(%d, %s, %d)' % (sockfd, data, flags))

        rc = socks[sockfd].send(data)
        sock.send(struct.pack('B', rc))
    elif cmd == CMD_SOCKET:
        af, type = struct.unpack('BB', recvall(sock, 2))
        id = len(socks)
        print("socket(%d, %d)" % (af, type))

        socks.append(socket.socket(socket.AF_INET, socket.SOCK_STREAM))
        sock.send(struct.pack('B', id))
