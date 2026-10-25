"""Envío de avisos por email al departamento de presupuestos."""
import logging
import smtplib
from email.message import EmailMessage

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import Actividad, Aviso, Rol, Usuario

log = logging.getLogger("prevenapp.avisos")


def destinatarios(db: Session) -> list[str]:
    """Emails que reciben los avisos: los del .env o, si no hay, los usuarios de presupuestos."""
    if settings.avisos_destinatarios:
        return [e.strip() for e in settings.avisos_destinatarios.split(",") if e.strip()]
    return list(
        db.scalars(select(Usuario.email).where(Usuario.rol == Rol.PRESUPUESTOS, Usuario.activo.is_(True)))
    )


def avisar_actividad_realizada(db: Session, actividad: Actividad, tecnico: Usuario) -> Aviso:
    """Envía el aviso "actividad realizada" y lo deja registrado en la tabla avisos."""
    fecha = actividad.fecha_realizacion.strftime("%d/%m/%Y")
    asunto = f"Actividad realizada - Presupuesto {actividad.codigo_presupuesto}"
    cuerpo = (
        "Se ha marcado una actividad como realizada en PrevenApp.\n\n"
        f"Técnico: {tecnico.nombre}\n"
        f"Presupuesto: {actividad.codigo_presupuesto}\n"
        f"Importe sin IVA: {actividad.importe_presupuesto:.2f} €\n"
        f"Fecha de realización: {fecha}\n"
        f"Cliente: {actividad.cliente.nombre}\n"
        f"Actividad: {actividad.tipo.nombre} ({actividad.anio})\n"
    )
    para = destinatarios(db)
    aviso = Aviso(actividad_id=actividad.id, destinatarios=", ".join(para), asunto=asunto, cuerpo=cuerpo)

    if not para:
        aviso.error = "No hay destinatarios: crea un usuario con rol presupuestos o define AVISOS_DESTINATARIOS"
    elif not settings.smtp_host:
        # Sin servidor de correo configurado: solo se registra (útil en desarrollo)
        aviso.error = "SMTP no configurado: el aviso se ha registrado pero no se ha enviado"
        log.info("Aviso (sin enviar) para %s: %s", para, asunto)
    else:
        mensaje = EmailMessage()
        mensaje["From"] = settings.avisos_remitente
        mensaje["To"] = ", ".join(para)
        mensaje["Subject"] = asunto
        mensaje.set_content(cuerpo)
        try:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
                if settings.smtp_tls:
                    smtp.starttls()
                if settings.smtp_usuario:
                    smtp.login(settings.smtp_usuario, settings.smtp_password or "")
                smtp.send_message(mensaje)
            aviso.enviado = True
        except (OSError, smtplib.SMTPException) as error:
            # Si falla el correo, la actividad sigue marcada como realizada; el fallo queda anotado
            aviso.error = f"Error al enviar: {error}"
            log.warning("No se pudo enviar el aviso: %s", error)

    db.add(aviso)
    db.commit()
    return aviso
