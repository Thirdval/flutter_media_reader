#!/usr/bin/env python3
"""Writes the example's text, table and archive samples into
assets/samples.

    python3 tool/make_texts.py

- Sermon notes.txt: a page of prose.
- README.md: Markdown with a link and an image.
- settings.json: JSON as a server writes it, on one line.
- sync.log: thirty thousand lines of a made-up log, over a megabyte.
- attendance.csv: a hundred thousand rows, with a header.
- photos.zip: a zip with folders, a nested zip, and two of the pictures.
- logs.tar.gz: a gzipped tar of two logs.

Everything is made up here: no other file's content is in them, apart
from the example's own pictures.
"""

import io
import json
import os
import random
import tarfile
import zipfile

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "samples")
rng = random.Random(2026)

NAMES = [
    "Ruth Adeyemi", "Daniel Okoro", "Miriam Haddad", "Samuel Osei",
    "Grace Mensah", "Peter Novak", "Esther Kim", "Joseph Bello",
]
SERVICES = ["Morning", "Evening", "Midweek", "Youth", "Prayer"]


def write(name, data):
    with open(os.path.join(OUT, name), "wb") as file:
        file.write(data)
    print("%s: %d bytes" % (name, len(data)))


prose = """Notes for Sunday, 4 October

Harvest is the oldest of our festivals, and the plainest. We bring what
the year gave, and we say thank you. That is all of it, and it is enough.

Three things to say this morning.

First, that gratitude is a habit before it is a feeling. The people who
brought the first fruits to the temple did not wait until they felt
grateful. They walked. The feeling followed the walking, as it usually
does.

Second, that a harvest is never one person's. Nobody grows a field
alone. The rain was not ours, the seed was not ours, and the hands that
helped were not all ours either. So the thanks is not private.

Third, that what we bring is meant to be given on. The loaves on the
table this morning go to the food bank on Monday. Harvest that stays on
the altar is decoration; harvest that goes out the door is worship.

Reading: Deuteronomy 26, verses 1 to 11.

Hymns: Come, ye thankful people, come; We plough the fields and scatter;
Now thank we all our God.

Notices: the harvest supper is on Saturday at six. Bring a dish to share,
and a chair if you can. The rota for October is on the noticeboard and
in the app.
"""
write("Sermon notes.txt", prose.encode("utf-8"))

readme = """# Harvest supper

Saturday 10 October, from **six** in the hall.

## What to bring

- A dish to share (savoury or sweet)
- A chair, if you can
- Your own cup: we are trying to use fewer paper ones

## The plan

| Time | What |
| --- | --- |
| 18:00 | Doors open |
| 18:30 | Grace, and food |
| 19:30 | Songs, with the youth band |
| 20:30 | Clearing away (everyone) |

The full [rota for October](https://tendvine.example/rota) is in the
app. Questions to Ruth.

![The hall, set for supper](https://tendvine.example/hall.jpg)

> Harvest that goes out the door is worship.
"""
write("README.md", readme.encode("utf-8"))

settings = {
    "community": "Ignite Church",
    "rota": {"weeks": 5, "roles": ["Welcome", "Sound", "Readings"]},
    "members": [{"name": name, "canExport": i % 2 == 0} for i, name in enumerate(NAMES)],
    "harvest": {"date": "2026-10-10", "time": "18:00", "bringADish": True},
}
write("settings.json", json.dumps(settings, separators=(",", ":")).encode("utf-8"))

lines = []
seconds = 0
for i in range(30000):
    seconds += rng.randint(1, 40)
    level = rng.choice(["INFO", "INFO", "INFO", "DEBUG", "WARN"])
    what = rng.choice([
        "synced room %d, %d messages" % (rng.randint(1, 40), rng.randint(0, 200)),
        "uploaded %s (%d KB)" % (rng.choice(["photo", "voice note", "document"]), rng.randint(20, 9000)),
        "resolved %d files for %s" % (rng.randint(1, 12), rng.choice(NAMES)),
        "reconnected after %d ms" % rng.randint(100, 9000),
        "harvest supper rota updated by %s" % rng.choice(NAMES) if i % 7000 == 100 else "heartbeat",
    ])
    lines.append("2026-10-%02d %02d:%02d:%02d %-5s %s" % (
        1 + seconds // 86400, seconds % 86400 // 3600, seconds % 3600 // 60, seconds % 60, level, what))
write("sync.log", ("\n".join(lines) + "\n").encode("utf-8"))

rows = ["id,date,service,attendance,note"]
for i in range(100000):
    day = 1 + i % 28
    month = 1 + (i // 28) % 12
    note = '"' + rng.choice(["", "", "", "Harvest, with supper", "Baptism", "All age"]) + '"'
    rows.append("%d,2026-%02d-%02d,%s,%d,%s" % (
        i + 1, month, day, SERVICES[i % len(SERVICES)], rng.randint(20, 240), note))
write("attendance.csv", ("\n".join(rows) + "\n").encode("utf-8"))

with open(os.path.join(OUT, "banner.png"), "rb") as file:
    banner = file.read()
with open(os.path.join(OUT, "candle.gif"), "rb") as file:
    candle = file.read()

inner = io.BytesIO()
with zipfile.ZipFile(inner, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.writestr("inside/deep.txt", "A file inside a zip inside a zip.\n")
photos = io.BytesIO()
with zipfile.ZipFile(photos, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.writestr("README.md", readme)
    zf.writestr("hall/banner.png", banner, compress_type=zipfile.ZIP_STORED)
    zf.writestr("hall/candle.gif", candle, compress_type=zipfile.ZIP_STORED)
    zf.writestr("notes/Sermon notes.txt", prose)
    zf.writestr("more.zip", inner.getvalue(), compress_type=zipfile.ZIP_STORED)
write("photos.zip", photos.getvalue())

logs = io.BytesIO()
with tarfile.open(fileobj=logs, mode="w:gz") as tf:
    for name, text in (("sync-1.log", "\n".join(lines[:200]) + "\n"), ("sync-2.log", "\n".join(lines[200:400]) + "\n")):
        data = text.encode("utf-8")
        info = tarfile.TarInfo("logs/" + name)
        info.size = len(data)
        tf.addfile(info, io.BytesIO(data))
write("logs.tar.gz", logs.getvalue())
