# Phone to Python

Phone and PC on same Wi-Fi:

Phone
  |
  | HTTP REST
  v
PC LAN IP : 8000
  |
  v
FastAPI
  |
  v
Repository / PostgreSQL

Never put `localhost` in the Android app when Python is running on the PC.

Example PC:
192.168.1.20

Android:
http://192.168.1.20:8000

If the phone browser cannot open `/health`, fix the network/firewall before testing Flutter.
