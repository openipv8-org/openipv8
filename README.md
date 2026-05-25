# openipv8
IPv8 implementation and example.

## What is IPv8
Specification: [https://www.ietf.org/archive/id/draft-thain-ipv8-00.html](https://www.ietf.org/archive/id/draft-thain-ipv8-00.html)

**Issue:** IPv4 uses 32 bits to store addresses. This is an issue because it's not enough IP addresses for each person to get their own.

**Solution:** 
IPv4 has a field called "Options" which is rarely used. What if we simply crammed extra address bits into the options field while keeping the rest of the packet structure the same? And then just set the version field to 8 instead of 4 so that routers know to look in the option field for the extra address bytes. This is what IPv8 does.

Note: openipv8 slightly changes the IPv8 packet structure. We interleave the address bytes in order to maintain backwards compatability with IPv4. 
```
s.s.s.s
s.s.s.s
d.d.d.d
d.d.d.d
```
to
```
s.s.s.s
d.d.d.d
s.s.s.s
d.d.d.d
```

## Backwards Compatibility
The IPv8 proposal on ietf.org advertises itself as fully backwards compatible with existing IPv4 infrastructure.

> Networks that have not deployed IPv8 continue to operate unchanged. IPv8 border routers strip the r.r.r.r prefix for IPv4-only destinations

In reality this is not fully true. IPv4 routers drop packets that they see with the IP version 8 instead of 4. *However*, if the client detects that the packet is dropped, it can change the IP version to 4 and set the reserved flag bit to true (to mark the packet as IPv8 in a way that IPv4 routers will not drop) without modifying the packet in any other way. The IPv4 router will then be able to accept and transmit the packet. RFC specification requires that routers ignore the reserved bit so it is safe to use it to mark a packet as IPv8. *But* the IPv4 router will only know where to route the packet on the IPv4 part of the network. The last node on the IPv4 part of the network must be an IPv8 router in order to route the packet to its final destination. Note that the target IPv8 device may itself be the last node on the IPv4 part of the network.

### For Example
Suppose Alice and Bob wish to communicate. Alice has an IPv4 router and Bob has an IPv8 router. 

Because Alice has an IPv4 router, she must ensure the IPv4 part of her address is unique. But because Bob has an IPv8 router, the IPv4 part of his address does *not* need to be unique *to recieve IPv8 packets*.

Suppose the following devices
- Alice (IPv8 device): 9.9.9.2.9.9.9.1
- Router1 (IPv4 device): 9.9.9.1
- Router2 (IPv8 device): 8.8.8.1
- Bob (IPv8 device): 8.8.8.1.9.9.9.1

that are connected as so:  
Alice <----> Router1 <----> Router2 <----> Bob

1) Alice sends Router1 the packet "This is an IPv8 packet containing the message 'hello' from 9.9.9.2.9.9.9.1 to 8.8.8.1.9.9.9.1".
2) Router1 realizes the IP version is 8 and that it doesn't support version 8 so it drops the packet.
3) Alice has not heard a response from Bob, so she assumes the packet has been dropped.
4) Alice sets the IP version to 4, sets the reserved bit, and resends the packet. Bob's full 8-byte address is still contained in the packet, but Router1 will only be able to read the first half of it.
5) Router1 reads the packet as "This is an IPv4 packet containing the message 'hello' from 9.9.9.2 to 8.8.8.1". It sends the packet to Router2.
6) Router2 is an IPv8 device so it recognizes the packet from Router1 as an IPv8 packet due to the reserved flag bit being set, and reads it as the original "This is an IPv8 packet containing the message 'hello' from 9.9.9.2.9.9.9.1 to 8.8.8.1.9.9.9.1". Router2 then forwards the packet to Bob.
7) Bob recieves "This is an IPv8 packet containing the message 'hello' from 9.9.9.2.9.9.9.1 to 8.8.8.1.9.9.9.1". Success!

## Run the example
You must have Zig 0.15.2 installed. You can get it here [https://ziglang.org/download/](https://ziglang.org/download/) . I tried to use Zig 0.16.0, but 0.16 COMPLETELY overhauled all I/O interfaces, and I couldn't figure out where everything went so we're staying on 0.15.2.

Note: Uses posix sockets. It will run on Linux and maybe BSD. It will not run on Windows. I'm pretty sure it will not run on Mac either.

Note: Sends and recieves raw IP packets. This requires root privileges.

openipv8 uses jvbuild as its build system. You can get it here [https://github.com/vExcess/jvbuild](https://github.com/vExcess/jvbuild) .

### Run the IPv8 server
```sh
# compile the server
jvbuild build example_server

# run the server (requires root)
sudo ./jvbuild-out/example_server
```

### Run the IPv8 client
```sh
# compile the client
jvbuild build example_client

# run the client (requires root)
sudo ./jvbuild-out/example_client
```

The example simulates an IPv8 device (the client) sending an IPv8 device (the server) an IPv8 packet through an IPv4 router (the host operating system).

## Security Note
This code is not well vetted. There might be memory vulnerabilities in it. You can imagine that a program that parses incoming network packets running with root privileges might be an issue if it's vulnerable. I recommend compiling it with the `-O=safe` or `-O=debug` flag (e.g. `jvbuild build example_server -O=safe`). In safe mode and debug mode Zig adds memory safety railguards that catch out of bounds accesses on arrays, double-frees, use-after-frees, and memory leaks.

Zig mogs on C

## ToDo
- Implement an IPv8 kernel driver for Linux.
- Implement UDP and TCP support ontop of IPv8
- Maybe we want to add non-address IP options fields parsing? Probably not, Linux automatically clears the options field for incoming packets and they're not often used to begin with.