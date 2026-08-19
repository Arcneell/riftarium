"""E-mails transactionnels : vérification d'adresse et réinitialisation de mot de passe.

SMTP_HOST vide → « mode console » : le message est loggé au lieu d'être envoyé
(c'est le mode développement). Sinon, envoi via SMTP OVH : SSL implicite sur le
port 465, STARTTLS sur les autres ports (587). Les fonctions sont appelées en
tâche de fond (BackgroundTasks) : un échec SMTP est loggé mais ne fait jamais
échouer la requête HTTP (robustesse + anti-énumération des comptes).
"""

from __future__ import annotations

import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formatdate, make_msgid, parseaddr

from .config import settings

log = logging.getLogger("riftarium.mailer")

SUBJECT_VERIFY = "Riftarium — confirmez votre adresse e-mail"
SUBJECT_RESET = "Riftarium — réinitialisation de votre mot de passe"

_BODY_VERIFY = """Bonjour,

Bienvenue sur Riftarium ! Pour confirmer votre adresse e-mail, ouvrez ce lien :

{link}

Ce lien est valable 7 jours. Si vous n'êtes pas à l'origine de cette demande,
vous pouvez ignorer ce message.

— L'équipe Riftarium
"""

_BODY_RESET = """Bonjour,

Une réinitialisation du mot de passe de votre compte Riftarium a été demandée.
Pour choisir un nouveau mot de passe, ouvrez ce lien :

{link}

Ce lien est valable 60 minutes et ne peut servir qu'une seule fois. Si vous
n'êtes pas à l'origine de cette demande, ignorez ce message : votre mot de
passe reste inchangé.

— L'équipe Riftarium
"""


def _from_domain() -> str:
    """Domaine de l'expéditeur, utilisé pour un Message-ID propre."""
    address = parseaddr(settings.mail_from)[1]
    if "@" in address:
        return address.rsplit("@", 1)[1]
    return "riftarium.re"


def _build_message(to: str, subject: str, body: str) -> EmailMessage:
    message = EmailMessage()
    message["From"] = settings.mail_from
    message["To"] = to
    message["Subject"] = subject
    message["Date"] = formatdate(localtime=False)
    message["Message-ID"] = make_msgid(domain=_from_domain())
    message.set_content(body, charset="utf-8")
    return message


def _deliver(smtp: smtplib.SMTP, message: EmailMessage) -> None:
    if settings.smtp_user:
        smtp.login(settings.smtp_user, settings.smtp_password)
    smtp.send_message(message)


def send_email(to: str, subject: str, body: str) -> None:
    """Envoie un e-mail texte brut UTF-8. Ne lève jamais : l'échec est loggé.

    Appelé en tâche de fond pour ne pas bloquer la requête HTTP.
    """
    if not settings.smtp_host:
        log.info("mode console — e-mail pour %s : %s\n%s", to, subject, body)
        return
    try:
        message = _build_message(to, subject, body)
        context = ssl.create_default_context()
        if settings.smtp_port == 465:
            with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15, context=context) as smtp:
                _deliver(smtp, message)
        else:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
                smtp.starttls(context=context)
                _deliver(smtp, message)
        log.info("e-mail envoyé à %s (%s)", to, subject)
    except Exception:
        log.exception("échec d'envoi SMTP vers %s (%s)", to, subject)


def send_verification_email(to: str, token: str) -> None:
    link = f"{settings.base_url}/verification-email?token={token}"
    send_email(to, SUBJECT_VERIFY, _BODY_VERIFY.format(link=link))


def send_reset_email(to: str, token: str) -> None:
    link = f"{settings.base_url}/reinitialisation?token={token}"
    send_email(to, SUBJECT_RESET, _BODY_RESET.format(link=link))
