#!/usr/bin/env python3
"""
SOCKS5 Proxy через VPN интерфейс (wg0)
Простой прокси для split tunneling
"""

import socket
import threading
import struct
import select
import sys

def create_connection_through_vpn(target_host, target_port):
    """Создать соединение через VPN интерфейс (wg0)"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)
    # Привязываем к VPN IP чтобы использовать wg0
    vpn_ip = "10.110.236.62"  # Твой VPN IP
    try:
        sock.bind((vpn_ip, 0))
    except Exception as e:
        print(f"Bind error: {e}")
        # Если не удалось привязать, используем без bind
        pass
    sock.connect((target_host, target_port))
    return sock

def handle_socks5_client(client_socket):
    """Обработать SOCKS5 клиента"""
    try:
        # Получаем приветствие от клиента
        greeting = client_socket.recv(2)
        if len(greeting) < 2:
            return
        
        nmethods = greeting[1]
        methods = client_socket.recv(nmethods)
        
        # Отвечаем: no authentication required
        client_socket.send(b'\x05\x00')
        
        # Получаем запрос
        request = client_socket.recv(4)
        if len(request) < 4:
            return
        
        cmd = request[1]
        atyp = request[3]
        
        if cmd != 1:  # CONNECT
            client_socket.send(b'\x05\x07\x00\x01\x00\x00\x00\x00\x00\x00')
            return
        
        # Получаем адрес
        if atyp == 1:  # IPv4
            addr = socket.inet_ntoa(client_socket.recv(4))
        elif atyp == 3:  # Domain
            domain_len = client_socket.recv(1)[0]
            addr = client_socket.recv(domain_len).decode()
        else:
            client_socket.send(b'\x05\x08\x00\x01\x00\x00\x00\x00\x00\x00')
            return
        
        port = struct.unpack('!H', client_socket.recv(2))[0]
        
        # Создаем соединение через VPN
        try:
            remote_socket = create_connection_through_vpn(addr, port)
            
            # Отвечаем успех
            client_socket.send(b'\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00')
            
            # Перенаправляем трафик
            while True:
                readable, _, _ = select.select([client_socket, remote_socket], [], [], 1)
                
                if client_socket in readable:
                    data = client_socket.recv(4096)
                    if not data:
                        break
                    remote_socket.send(data)
                
                if remote_socket in readable:
                    data = remote_socket.recv(4096)
                    if not data:
                        break
                    client_socket.send(data)
        except Exception as e:
            print(f"Connection error: {e}")
            client_socket.send(b'\x05\x05\x00\x01\x00\x00\x00\x00\x00\x00')
    except Exception as e:
        print(f"Client error: {e}")
    finally:
        client_socket.close()

def start_proxy(host='127.0.0.1', port=1080):
    """Запустить SOCKS5 прокси"""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind((host, port))
    except Exception as e:
        print(f"Failed to bind: {e}")
        sys.exit(1)
    server.listen(100)
    
    print(f"SOCKS5 Proxy started on {host}:{port}")
    print(f"Traffic goes through VPN (wg0)")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            client, addr = server.accept()
            thread = threading.Thread(target=handle_socks5_client, args=(client,))
            thread.daemon = True
            thread.start()
    except KeyboardInterrupt:
        print("\nStopping proxy...")
    finally:
        server.close()

if __name__ == '__main__':
    start_proxy()
