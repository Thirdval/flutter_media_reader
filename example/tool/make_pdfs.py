#!/usr/bin/env python3
"""Writes the example's PDF samples into assets/samples.

    python3 tool/make_pdfs.py

- Rota_October.pdf: 300 pages of a made-up rota, over a megabyte, so the
  reader fetches it by ranges. Its first line links to a web address and
  its second to the last page. "Harvest supper" is on three pages.
- Accounts_2025.pdf: two pages, protected with the password "harvest"
  (RC4, 40 bits: the oldest scheme, which every PDF library opens).

The files are plain, uncompressed PDF 1.4 with the standard Helvetica,
made here from nothing: no other file's content is in them.
"""

import hashlib
import os
import struct

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "samples")

PAD = bytes([
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E,
    0x56, 0xFF, 0xFA, 0x01, 0x08, 0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68,
    0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
])


def rc4(key, data):
    s = list(range(256))
    j = 0
    for i in range(256):
        j = (j + s[i] + key[i % len(key)]) & 0xFF
        s[i], s[j] = s[j], s[i]
    out = bytearray(len(data))
    i = j = 0
    for n, byte in enumerate(data):
        i = (i + 1) & 0xFF
        j = (j + s[i]) & 0xFF
        s[i], s[j] = s[j], s[i]
        out[n] = byte ^ s[(s[i] + s[j]) & 0xFF]
    return bytes(out)


class Lock:
    """The standard security handler, revision 2."""

    PERMISSIONS = -4

    def __init__(self, password, file_id):
        padded = (password.encode("ascii") + PAD)[:32]
        self.owner = rc4(hashlib.md5(padded).digest()[:5], padded)
        self.key = hashlib.md5(
            padded + self.owner + struct.pack("<i", self.PERMISSIONS) + file_id
        ).digest()[:5]

    def dictionary(self):
        return (
            "<< /Filter /Standard /V 1 /R 2 /O <%s> /U <%s> /P %d >>"
            % (self.owner.hex(), rc4(self.key, PAD).hex(), self.PERMISSIONS)
        ).encode("ascii")

    def encrypt(self, data, number):
        key = hashlib.md5(
            self.key + struct.pack("<I", number)[:3] + b"\x00\x00"
        ).digest()[:10]
        return rc4(key, data)


def escape(line):
    return line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def pdf(pages, size=10, leading=13, annotations=None, password=None):
    """`pages` is a list of lists of lines. `annotations` maps a page
    number (from 1) to the text of its /Annots array, which may name the
    object of page n as {page:n}."""
    count = len(pages)
    file_id = hashlib.md5(("example-%d" % count).encode()).digest()
    lock = Lock(password, file_id) if password else None

    def page_object(n):
        return 4 + (n - 1) * 2

    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        (
            "<< /Type /Pages /Kids [%s] /Count %d >>"
            % (" ".join("%d 0 R" % page_object(n) for n in range(1, count + 1)), count)
        ).encode("ascii"),
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
        b"/Encoding /WinAnsiEncoding >>",
    ]
    for n, lines in enumerate(pages, start=1):
        content = ["BT /F1 %d Tf 56 744 Td %d TL" % (size, leading)]
        content += ["(%s) Tj T*" % escape(line) for line in lines]
        content.append("ET")
        stream = "\n".join(content).encode("ascii")
        content_number = page_object(n) + 1
        if lock:
            stream = lock.encrypt(stream, content_number)
        annots = ""
        if annotations and n in annotations:
            text = annotations[n]
            for target in range(1, count + 1):
                text = text.replace("{page:%d}" % target, "%d 0 R" % page_object(target))
            annots = " /Annots [%s]" % text
        objects.append(
            (
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
                "/Resources << /Font << /F1 3 0 R >> >> /Contents %d 0 R%s >>"
                % (content_number, annots)
            ).encode("ascii")
        )
        objects.append(
            b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream"
        )
    if lock:
        objects.append(lock.dictionary())

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % number + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for offset in offsets:
        out += b"%010d 00000 n \n" % offset
    encrypt = b"/Encrypt %d 0 R " % len(objects) if lock else b""
    hex_id = file_id.hex().encode("ascii")
    out += (
        b"trailer\n<< /Size %d /Root 1 0 R " % (len(objects) + 1)
        + encrypt
        + b"/ID [<" + hex_id + b"> <" + hex_id + b">] >>\n"
        + b"startxref\n%d\n%%%%EOF\n" % xref
    )
    return bytes(out)


NAMES = [
    "Ruth Adeyemi", "Daniel Okoro", "Miriam Haddad", "Samuel Osei",
    "Grace Mensah", "Peter Novak", "Esther Kim", "Joseph Bello",
    "Hannah Schmidt", "David Tan", "Lydia Santos", "Aaron Petit",
    "Naomi Wright", "Caleb Ibrahim", "Deborah Costa", "Isaac Lindqvist",
]
ROLES = [
    "Welcome", "Sound desk", "Readings", "Prayers", "Children's group",
    "Coffee", "Flowers", "Music", "Stewards", "Projection", "Car park",
    "Counting", "Setting up", "Clearing away",
]
TIMES = ["08:00", "09:30", "11:00", "16:00", "18:30"]
DAYS = ["Sunday", "Wednesday", "Friday"]
HARVEST = {12, 140, 288}


def rota():
    pages = []
    for page in range(1, 301):
        lines = [
            "The rota online: tendvine.example/rota" if page == 1
            else "Rota for October 2026, page %d of 300" % page,
            "Go to the last page" if page == 1 else "",
        ]
        if page in HARVEST:
            lines.append("Harvest supper: bring a dish to share, and a chair if you can")
        for row in range(50):
            seed = page * 31 + row * 17
            first = seed % len(NAMES)
            lines.append(
                "%-9s %2d October %s   %-17s %s and %s, with %s in reserve"
                % (
                    DAYS[seed % len(DAYS)],
                    1 + seed % 31,
                    TIMES[seed % len(TIMES)],
                    ROLES[seed % len(ROLES)] + ":",
                    NAMES[first],
                    # Three different people: the offsets never meet.
                    NAMES[(first + 1 + seed // 3 % 5) % len(NAMES)],
                    NAMES[(first + 7 + seed // 7 % 4) % len(NAMES)],
                )
            )
        pages.append(lines)
    # The first line is a link out, the second a link to the last page.
    annotations = {
        1: "<< /Type /Annot /Subtype /Link /Rect [56 741 250 754] "
        "/Border [0 0 0] /A << /S /URI /URI (https://tendvine.example/rota) >> >> "
        "<< /Type /Annot /Subtype /Link /Rect [56 728 160 741] "
        "/Border [0 0 0] /Dest [{page:300} /XYZ 0 792 0] >>"
    }
    return pdf(pages, annotations=annotations)


def accounts():
    return pdf(
        [
            [
                "Accounts for 2025",
                "",
                "Offerings                     48,210",
                "Hall hire                      6,480",
                "Harvest supper                 1,215",
            ],
            ["Notes to the accounts", "", "Examined by Peter Novak."],
        ],
        size=14,
        leading=20,
        password="harvest",
    )


for name, data in (("Rota_October.pdf", rota()), ("Accounts_2025.pdf", accounts())):
    with open(os.path.join(OUT, name), "wb") as file:
        file.write(data)
    print("%s: %d bytes" % (name, len(data)))
