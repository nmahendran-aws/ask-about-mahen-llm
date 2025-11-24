from pypdf import PdfReader
from docx import Document
import json

# Read LinkedIn PDF
try:
    reader = PdfReader("./data/profile.pdf")
    linkedin = ""
    for page in reader.pages:
        text = page.extract_text()
        if text:
            linkedin += text
except FileNotFoundError:
    linkedin = "LinkedIn profile not available"

# Read other data files
with open("./data/summary.txt", "r", encoding="utf-8") as f:
    summary = f.read()

with open("./data/style.txt", "r", encoding="utf-8") as f:
    style = f.read()

with open("./data/facts.json", "r", encoding="utf-8") as f:
    facts = json.load(f)

try:
    doc = Document("./data/resume.docx")
    resume = "\n".join([para.text for para in doc.paragraphs])
except Exception as e:
    resume = f"Resume not available: {e}"