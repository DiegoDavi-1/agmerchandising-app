import os
import cv2
import pytesseract
import re

PASTA = r'C:\Users\diego\Pictures\WhatsApp Images'

registros = []

for arquivo in os.listdir(PASTA):
    if arquivo.lower().endswith(('.jpg', '.png', '.jpeg')):
        caminho = os.path.join(PASTA, arquivo)
        img = cv2.imread(caminho)

        texto = pytesseract.image_to_string(img, lang='por')
        texto = texto.upper().strip()

        data_match = re.search(r'\d{2}/\d{2}/\d{4}', texto)
        hora_match = re.search(r'\d{2}:\d{2}', texto)
        local_match = re.search(r'LOCAL[:\s]+(.+)', texto)

        data = data_match.group() if data_match else None
        hora = hora_match.group() if hora_match else None
        local = local_match.group(1) if local_match else None

        registros.append({
            'arquivo': arquivo,
            'data': data,
            'hora': hora,
            'local': local
        })
