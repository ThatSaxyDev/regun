"""Local ordered TCP impairment harness. Delays both WebSocket directions.
TCP retransmission is not simulated packet loss; close a client to test reconnect.
"""
import argparse,asyncio,random
async def main():
 p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=3101);p.add_argument('--one-way-ms',type=float,default=50);p.add_argument('--jitter-ms',type=float,default=10);p.add_argument('--upstream-port',type=int,default=3100);args=p.parse_args()
 rng=random.Random(42)
 async def handle(reader,writer):
  upstream_r,upstream_w=await asyncio.open_connection('127.0.0.1',args.upstream_port)
  async def pipe(source,destination):
   queue=asyncio.Queue(maxsize=4096);loop=asyncio.get_running_loop()
   async def receive():
    deadline=0
    try:
     while chunk:=await source.read(262144):
      deadline=max(deadline,loop.time()+max(0,args.one_way_ms+rng.uniform(-args.jitter_ms,args.jitter_ms))/1000)
      await queue.put((deadline,chunk))
    finally:await queue.put((0,None))
   async def deliver():
    try:
     while True:
      deadline,chunk=await queue.get()
      if chunk is None:break
      await asyncio.sleep(max(0,deadline-loop.time()));destination.write(chunk);await destination.drain()
    finally:destination.close()
   try:await asyncio.gather(receive(),deliver())
   except (ConnectionError,asyncio.CancelledError):destination.close()
  await asyncio.gather(pipe(reader,upstream_w),pipe(upstream_r,writer))
 server=await asyncio.start_server(handle,'127.0.0.1',args.port)
 print(f'Ordered local TCP proxy: {args.one_way_ms*2:g}ms nominal RTT ±{args.jitter_ms:g}ms/direction',flush=True)
 async with server:await server.serve_forever()
asyncio.run(main())
