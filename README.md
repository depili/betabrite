## Ruby class for Alpha led matrix communication
This is a simple class I wrote to communicate with a 1990-era Betabrite led matrix. This should serve as a decent start for other led signs using the Alpha protocol.

See http://www.teksolutionsllc.com/download/alphaprotodoc.pdf for the protocol documentation.

You need also a serial interface that recognizes TTL level signals and a RJ12 cable and adapter. In my case I got the link working wiring RJ12 blue to pin 5, red to pin 2 and green to pin 2 and using MiniPiio v0.20 RS232 interface with raspberry pi 2. 