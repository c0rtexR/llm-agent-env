import asyncio
import websockets
import json
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

class IRCServer:
    def __init__(self):
        self.clients = {}
        self.channels = {}

    async def register(self, websocket, nickname):
        logger.debug(f"Registering new client with nickname: {nickname}")
        self.clients[websocket] = nickname
        await self.broadcast(f"{nickname} has joined the server")
        logger.debug(f"Sent welcome message to {nickname}")
        await websocket.send(json.dumps({"type": "connect", "content": f"Welcome {nickname}!"}))

    async def unregister(self, websocket):
        nickname = self.clients.pop(websocket, None)
        if nickname:
            await self.broadcast(f"{nickname} has left the server")
            for channel in self.channels.values():
                if websocket in channel:
                    channel.remove(websocket)

    async def broadcast(self, message, channel=None):
        if channel:
            recipients = self.channels.get(channel, set())
        else:
            recipients = self.clients.keys()
        
        for client in recipients:
            await client.send(json.dumps({"type": "message", "content": message}))

    async def handle_message(self, websocket, message):
        data = json.loads(message)
        command = data.get("command")
        content = data.get("content")
        sender = self.clients[websocket]

        if command == "JOIN":
            channel = content
            if channel not in self.channels:
                self.channels[channel] = set()
            self.channels[channel].add(websocket)
            await self.broadcast(f"{sender} has joined {channel}", channel)
        elif command == "PART":
            channel = content
            if channel in self.channels and websocket in self.channels[channel]:
                self.channels[channel].remove(websocket)
                await self.broadcast(f"{sender} has left {channel}", channel)
        elif command == "PRIVMSG":
            target, msg = content.split(" ", 1)
            if target.startswith("#"):
                await self.broadcast(f"{sender}: {msg}", target)
            else:
                recipient = next((ws for ws, nick in self.clients.items() if nick == target), None)
                if recipient:
                    await recipient.send(json.dumps({"type": "private", "sender": sender, "content": msg}))
        elif command == "LIST":
            channel_list = list(self.channels.keys())
            await websocket.send(json.dumps({"type": "channel_list", "channels": channel_list}))

    async def handler(self, websocket, path):
        try:
            logger.debug("New connection received")
            await websocket.send(json.dumps({"type": "connect", "content": "Please provide a nickname"}))
            message = await websocket.recv()
            data = json.loads(message)
            nickname = data.get("nickname")
            logger.debug(f"Received nickname: {nickname}")
            
            await self.register(websocket, nickname)
            
            async for message in websocket:
                await self.handle_message(websocket, message)
        except Exception as e:
            logger.error(f"Error in handler: {str(e)}")
        finally:
            await self.unregister(websocket)

irc_server = IRCServer()

start_server = websockets.serve(irc_server.handler, "0.0.0.0", 6668)

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()