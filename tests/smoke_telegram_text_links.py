"""Check Telegram text-link behavior with real Hermes events and synthetic updates."""

import os
import tempfile
import unittest

# Keep test state separate even if run inside an installed Hermes environment.
test_home = tempfile.TemporaryDirectory(prefix="hermes-telegram-test-")
os.environ["HERMES_HOME"] = test_home.name

from telegram import Message

from gateway.config import PlatformConfig
from gateway.platforms.base import MessageType
from plugins.platforms.telegram.adapter import TelegramAdapter


def utf16_length(text):
    return len(text.encode("utf-16-le")) // 2


class HiddenLinks(unittest.TestCase):
    def setUp(self):
        self.adapter = TelegramAdapter(PlatformConfig(enabled=True, token="offline-test"))

    def event(self, text, links=(), *, caption=False, channel=False):
        chat = {"id": -100123, "type": "channel", "title": "Test"}
        sender = {"id": 123, "is_bot": False, "first_name": "Test"}
        if not channel:
            chat = {"id": 123, "type": "private", "first_name": "Test"}

        body_field = "caption" if caption else "text"
        entity_field = "caption_entities" if caption else "entities"
        payload = {
            "message_id": 1,
            "date": 1788500000,
            "chat": chat,
            body_field: text,
            entity_field: [
                {
                    "type": "text_link",
                    "offset": utf16_length(text[:start]),
                    "length": utf16_length(text[start:end]),
                    "url": url,
                }
                for start, end, url in links
            ],
        }
        if not channel:
            payload["from"] = sender
        message = Message.de_json(payload, bot=None)
        kind = MessageType.DOCUMENT if caption else MessageType.TEXT
        return self.adapter._build_message_event(message, kind)

    def test_hidden_link(self):
        url = "https://example.com/article"
        self.assertIn(url, self.event("article", [(0, 7, url)]).text)

    def test_multiple_and_duplicate_links(self):
        article = "https://example.com/article"
        comments = "https://example.com/comments"
        links = [(0, 7, article), (8, 16, comments), (17, 23, article)]
        event = self.event("Article Comments Repeat", links)
        self.assertEqual(event.text.count(article), 1)
        self.assertIn(comments, event.text)

    def test_caption(self):
        url = "https://example.com/report"
        event = self.event("Read report", [(5, 11, url)], caption=True)
        self.assertIn("Read report", event.text)
        self.assertIn(url, event.text)

    def test_channel_post(self):
        url = "https://example.com/post"
        event = self.event("post", [(0, 4, url)], channel=True)
        self.assertIn(url, event.text)

    def test_utf16_offset_after_emoji(self):
        url = "https://example.com/uk"
        event = self.event("😀 Читай тут зараз", [(2, 11, url)])
        self.assertTrue(event.text.startswith("😀 Читай тут"))
        self.assertIn(url, event.text)
        self.assertLess(event.text.index(url), event.text.index("зараз"))

    def test_visible_url_and_plain_text(self):
        url = "https://example.com/article"
        self.assertEqual(self.event(url, [(0, len(url), url)]).text, url)
        self.assertEqual(self.event("звичайний текст").text, "звичайний текст")


if __name__ == "__main__":
    try:
        unittest.main(verbosity=2)
    finally:
        test_home.cleanup()
