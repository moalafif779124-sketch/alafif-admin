#!/usr/bin/env python3
"""
Firebase Authentication Helper
Runs firebase login:ci in a pseudo-terminal so we can capture the URL
"""
import os
import sys
import pty
import select
import subprocess
import time
import fcntl
import signal

def set_nonblocking(fd):
    """Set a file descriptor to non-blocking mode."""
    flags = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

def run_firebase_login_ci():
    """Run firebase login:ci and capture output."""
    env = os.environ.copy()
    env['PATH'] = f"{os.path.expanduser('~/.local/bin')}:{env.get('PATH', '')}"
    
    master_fd, slave_fd = pty.openpty()
    
    proc = subprocess.Popen(
        ['firebase', 'login:ci', '--no-localhost'],
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        env=env,
        close_fds=True,
    )
    
    os.close(slave_fd)
    set_nonblocking(master_fd)
    
    output = b''
    start_time = time.time()
    timeout = 30  # 30 seconds max
    
    while True:
        elapsed = time.time() - start_time
        if elapsed > timeout:
            print("TIMEOUT: Firebase CLI didn't respond in time")
            os.kill(proc.pid, signal.SIGTERM)
            break
        
        try:
            r, w, e = select.select([master_fd], [], [], 1.0)
            if r:
                data = os.read(master_fd, 4096)
                if data:
                    output += data
                    decoded = output.decode('utf-8', errors='replace')
                    # Check if we got the URL
                    if 'https://' in decoded and 'code=' in decoded:
                        print(decoded)
                        break
        except (OSError, select.error):
            break
        
        # Check if process is done
        ret = proc.poll()
        if ret is not None:
            # Read remaining output
            try:
                while True:
                    data = os.read(master_fd, 4096)
                    if not data:
                        break
                    output += data
            except OSError:
                pass
            break
    
    os.close(master_fd)
    final_output = output.decode('utf-8', errors='replace')
    
    # Extract URL
    import re
    urls = re.findall(r'https://[^\s]+', final_output)
    for url in urls:
        if 'accounts.google.com' in url or 'firebase' in url:
            print("\n" + "="*60)
            print("🔗 افتح هذا الرابط في متصفح هاتفك:")
            print(url)
            print("="*60)
            print("\nبعد تسجيل الدخول، سيظهر لك رمز.")
            print("انسخ الرمز وأرسله لي لأكمل الإعداد.")
            break
    
    return final_output

if __name__ == '__main__':
    run_firebase_login_ci()
