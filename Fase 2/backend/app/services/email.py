"""Envío de correos por SMTP (HU-I). Con Gmail: smtp.gmail.com:587 y una contraseña de aplicación.

Sin SMTP configurado (settings.email_enabled en False):
- en development el correo se escribe en los logs del backend (`docker compose logs backend`), para que
  cualquiera del equipo pueda probar sin las credenciales;
- en otro ambiente se lanza EmailError: nunca se exponen códigos en los logs de producción.
"""

import asyncio
import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr
from html import escape
from pathlib import Path

from app.core.config import settings

logger = logging.getLogger("adoptify")

# Logo de la app (cuadrado naranjo con la huella blanca de Icons.pets), incrustado en el correo como imagen
# en línea: así se ve sin depender de un servidor de imágenes ni de que el cliente las descargue
LOGO_CID = "adoptify-logo"
LOGO_PNG = (Path(__file__).resolve().parent.parent / "assets" / "email_logo.png").read_bytes()


class EmailError(Exception):
    """No se pudo enviar el correo (sin proveedor configurado o el servidor SMTP falló)."""


def _deliver(message: EmailMessage) -> None:
    # smtplib es bloqueante: se llama dentro de asyncio.to_thread
    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as smtp:
        smtp.starttls(context=ssl.create_default_context())
        smtp.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        smtp.send_message(message)


async def send_email(
    to: str, subject: str, text: str, html: str | None = None, images: dict[str, bytes] | None = None
) -> None:
    """images: PNG en línea por su Content-ID; en el HTML se usan como <img src="cid:...">."""
    if not settings.email_enabled:
        if settings.ENVIRONMENT == "development":
            logger.warning("Correo sin enviar (falta SMTP en el .env). Para: %s | %s\n%s", to, subject, text)
            return
        raise EmailError("No hay un proveedor de correo configurado.")

    message = EmailMessage()
    message["From"] = formataddr((settings.EMAIL_FROM_NAME, settings.EMAIL_FROM or settings.SMTP_USER))
    message["To"] = to
    message["Subject"] = subject
    message.set_content(text)
    if html:
        message.add_alternative(html, subtype="html")
        html_part = message.get_payload()[-1]
        for cid, data in (images or {}).items():
            html_part.add_related(data, "image", "png", cid=f"<{cid}>", filename=f"{cid}.png")
    try:
        await asyncio.to_thread(_deliver, message)
    except (smtplib.SMTPException, OSError) as exc:
        logger.error("No se pudo enviar el correo a %s: %s", to, exc)
        raise EmailError("El servidor de correo no respondió.") from exc


async def send_verification_code(to: str, code: str, purpose: str, name: str | None = None) -> None:
    """Correo con el código de 6 dígitos para iniciar sesión o para activar la verificación en dos pasos."""
    minutes = settings.LOGIN_CODE_MINUTES
    first_name = name.split()[0] if name and name.strip() else None
    if purpose == "login":
        title = "Tu código para iniciar sesión"
        intro = "Usa este código para terminar de iniciar sesión en Adoptify."
        warning = (
            "¿No fuiste tú? Alguien escribió tu contraseña correcta. No compartas este código y cambia tu "
            "contraseña lo antes posible."
        )
    else:
        title = "Activa la verificación en dos pasos"
        intro = "Ingresa este código en la app para proteger tu cuenta con la verificación en dos pasos."
        warning = "¿No lo pediste tú? Ignora este correo: la verificación no se activará sin este código."

    greeting = f"Hola, {first_name}:" if first_name else "Hola:"
    text = (
        f"{greeting}\n\n{intro}\n\nTu código es: {code}\n\nVence en {minutes} minutos.\n\n{warning}\n\n"
        "Adoptify · Rescate y adopción animal. Este es un correo automático, no lo respondas."
    )
    html = _code_email_html(
        code=code, title=title, greeting=greeting, intro=intro, warning=warning, minutes=minutes
    )
    await send_email(to, "Tu código de verificación de Adoptify", text, html, images={LOGO_CID: LOGO_PNG})


def _code_email_html(*, code: str, title: str, greeting: str, intro: str, warning: str, minutes: int) -> str:
    """Correo con la identidad de la app (mismos colores que app/theme.dart y el portal).

    Hecho con tablas y estilos en línea, porque Gmail y Outlook ignoran las hojas de estilo y el CSS moderno.
    """
    # Paleta de la app: naranjo de marca, fondo crema, texto piedra
    orange, orange_strong, orange_soft, orange_border = "#EA580C", "#C2410C", "#FFF7ED", "#FED7AA"
    background, surface, text, muted, border = "#FAF9F6", "#FFFFFF", "#292524", "#78716C", "#E7E5E4"
    font = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
    logo_cid = LOGO_CID
    digits = "".join(
        f'<td style="padding:0 3px"><div style="width:40px;height:52px;line-height:52px;background:{surface};'
        f"border:1px solid {orange_border};border-radius:10px;font-size:26px;font-weight:800;color:{orange_strong};"
        f'text-align:center;font-family:{font}">{digit}</div></td>'
        for digit in code
    )
    return f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light">
<title>{escape(title)}</title>
</head>
<body style="margin:0;padding:0;background:{background}">
<div style="display:none;max-height:0;overflow:hidden;opacity:0">Tu código es {code}. Vence en {minutes} minutos.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{background};font-family:{font}">
<tr><td align="center" style="padding:32px 16px">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px">
    <tr><td align="center" style="padding-bottom:24px">
      <table role="presentation" cellpadding="0" cellspacing="0"><tr>
        <td style="width:40px;height:40px"><img src="cid:{logo_cid}" width="40" height="40" alt="Adoptify"
          style="display:block;border:0;border-radius:12px;background:{orange}"></td>
        <td style="padding-left:10px;font-size:26px;font-weight:800;letter-spacing:-0.5px;color:{text}">
          adoptify<span style="color:{orange}">.</span></td>
      </tr></table>
    </td></tr>
    <tr><td style="background:{surface};border:1px solid {border};border-radius:20px;padding:32px 28px">
      <h1 style="margin:0 0 16px;font-size:22px;line-height:1.3;color:{text};text-align:center">{escape(title)}</h1>
      <p style="margin:0 0 8px;font-size:15px;line-height:1.6;color:{text}">{escape(greeting)}</p>
      <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:{text}">{escape(intro)}</p>
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
        <tr><td align="center" style="background:{orange_soft};border-radius:16px;padding:20px 8px">
          <table role="presentation" cellpadding="0" cellspacing="0"><tr>{digits}</tr></table>
          <p style="margin:14px 0 0;font-size:13px;color:{orange_strong};font-weight:600">
            Vence en {minutes} minutos</p>
        </td></tr>
      </table>
      <p style="margin:24px 0 0;padding:14px 16px;background:{background};border-radius:12px;font-size:13px;
        line-height:1.5;color:{muted}">{escape(warning)}</p>
    </td></tr>
    <tr><td align="center" style="padding:24px 16px 0;font-size:12px;line-height:1.6;color:{muted}">
      Adoptify · Rescate y adopción animal<br>
      Este es un correo automático, no lo respondas.
    </td></tr>
  </table>
</td></tr>
</table>
</body>
</html>"""
