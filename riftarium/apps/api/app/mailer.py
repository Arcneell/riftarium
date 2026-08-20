"""E-mails transactionnels : vérification d'adresse, réinitialisation de mot de
passe et notifications de modération des decks.

SMTP_HOST vide → « mode console » : le message est loggé au lieu d'être envoyé
(c'est le mode développement). Sinon, envoi via SMTP OVH : SSL implicite sur le
port 465, STARTTLS sur les autres ports (587). Les fonctions sont appelées en
tâche de fond (BackgroundTasks, ou thread dédié hors contexte requête) : un
échec SMTP est loggé mais ne fait jamais échouer la requête HTTP (robustesse +
anti-énumération des comptes).

Chaque envoi est multipart (texte + HTML) : le HTML reprend le thème parchemin
du site ; le texte brut reste lisible si le client masque les images.
"""

from __future__ import annotations

import logging
import smtplib
import ssl
import threading
from dataclasses import dataclass
from email.message import EmailMessage
from email.utils import formatdate, make_msgid, parseaddr
from html import escape

from .config import settings

log = logging.getLogger("riftarium.mailer")

SUBJECT_VERIFY = "Confirmez votre adresse — Riftarium"
SUBJECT_RESET = "Réinitialisez votre mot de passe — Riftarium"

# Couleurs alignées sur main.css (parchemin / encre / or).
_INK = "#16283a"
_INK_STRONG = "#0a1428"
_MUTED = "#6b6450"
_GOLD = "#b08a3e"
_GOLD_DEEP = "#7a5d28"
_PAPER = "#fdfaf2"
_PAPER_OUTER = "#ede4cf"
_HEX = "#0b8f84"


@dataclass(frozen=True)
class MailCopy:
    """Contenu d'un e-mail transactionnel (texte + HTML partagent ces champs)."""

    subject: str
    preheader: str
    title: str
    paragraphs: tuple[str, ...]
    cta: str
    validity: str
    ignore: str


_VERIFY = MailCopy(
    subject=SUBJECT_VERIFY,
    preheader="Un clic pour confirmer votre adresse. Lien valable 7 jours.",
    title="Bienvenue sur Riftarium",
    paragraphs=(
        "Votre compte est créé : cartothèque, collection et deck builder vous attendent.",
        "Il ne reste plus qu'à confirmer que cette adresse vous appartient.",
    ),
    cta="Confirmer mon adresse",
    validity="Ce lien expire dans 7 jours.",
    ignore="Si vous n'avez pas créé de compte Riftarium, ignorez cet e-mail.",
)

_RESET = MailCopy(
    subject=SUBJECT_RESET,
    preheader="Choisissez un nouveau mot de passe. Lien valable 60 minutes, usage unique.",
    title="Réinitialisation du mot de passe",
    paragraphs=(
        "Une demande de réinitialisation a été faite pour votre compte Riftarium.",
        "Si c'est bien vous, choisissez un nouveau mot de passe ci-dessous.",
    ),
    cta="Choisir un nouveau mot de passe",
    validity="Ce lien expire dans 60 minutes et ne peut servir qu'une seule fois.",
    ignore=(
        "Si vous n'êtes pas à l'origine de cette demande, ignorez cet e-mail : "
        "votre mot de passe actuel reste inchangé."
    ),
)


def _from_domain() -> str:
    """Domaine de l'expéditeur, utilisé pour un Message-ID propre."""
    address = parseaddr(settings.mail_from)[1]
    if "@" in address:
        return address.rsplit("@", 1)[1]
    return "riftarium.re"


def _logo_url() -> str:
    return f"{settings.base_url}/favicon.svg"


def _footer_note(copy: MailCopy) -> str:
    """Note de bas de message : validité puis mention « ignorer », champs vides omis."""
    return " ".join(part for part in (copy.validity, copy.ignore) if part)


def _plain(copy: MailCopy, link: str) -> str:
    body = "\n\n".join(copy.paragraphs)
    return (
        f"{copy.title}\n\n"
        f"{body}\n\n"
        f"{copy.cta} :\n{link}\n\n"
        f"{_footer_note(copy)}\n\n"
        "— L'équipe Riftarium\n"
        f"{settings.base_url}\n"
    )


def _html(copy: MailCopy, link: str) -> str:
    """Mise en page table (Outlook) + styles inline. Logo distant : le bandeau reste lisible sans images."""
    href = escape(link, quote=True)
    logo = escape(_logo_url(), quote=True)
    paragraphs = "".join(
        f'<p style="margin:0 0 14px;font-size:16px;line-height:1.55;color:{_INK};">{escape(paragraph)}</p>'
        for paragraph in copy.paragraphs
    )
    return f"""\
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light">
<title>{escape(copy.subject)}</title>
</head>
<body style="margin:0;padding:0;background:{_PAPER_OUTER};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">{escape(copy.preheader)}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:{_PAPER_OUTER};">
  <tr>
    <td align="center" style="padding:28px 12px;">
      <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="width:600px;max-width:100%;background:{_PAPER};border:1px solid rgba(138,106,47,0.28);">
        <tr><td style="height:5px;background:{_GOLD};font-size:0;line-height:0;">&nbsp;</td></tr>
        <tr>
          <td align="center" style="padding:28px 32px 12px;">
            <img src="{logo}" width="72" height="72" alt="Riftarium" style="display:block;border:0;width:72px;height:72px;">
            <p style="margin:12px 0 0;font-family:Georgia,'Times New Roman',serif;font-size:22px;letter-spacing:0.12em;color:{_GOLD_DEEP};">RIFTARIUM</p>
            <p style="margin:6px 0 0;font-family:Georgia,serif;font-size:13px;color:{_MUTED};">Le compagnon Riftbound</p>
          </td>
        </tr>
        <tr>
          <td style="padding:8px 32px 0;">
            <hr style="border:0;border-top:1px solid rgba(138,106,47,0.28);margin:0;">
          </td>
        </tr>
        <tr>
          <td style="padding:28px 32px 8px;font-family:Georgia,'Times New Roman',serif;">
            <h1 style="margin:0 0 18px;font-size:26px;line-height:1.25;font-weight:normal;color:{_INK_STRONG};">{escape(copy.title)}</h1>
            {paragraphs}
            <table role="presentation" cellspacing="0" cellpadding="0" style="margin:24px 0 8px;">
              <tr>
                <td align="center" bgcolor="{_GOLD}" style="border-radius:6px;">
                  <a href="{href}" style="display:inline-block;padding:14px 28px;font-family:Georgia,serif;font-size:16px;color:{_PAPER};text-decoration:none;font-weight:bold;">{escape(copy.cta)}</a>
                </td>
              </tr>
            </table>
            <p style="margin:18px 0 0;font-size:13px;line-height:1.5;color:{_MUTED};">{escape(_footer_note(copy))}</p>
            <p style="margin:16px 0 0;font-size:12px;line-height:1.5;color:{_MUTED};word-break:break-all;">Si le bouton ne fonctionne pas, copiez ce lien dans votre navigateur :<br><a href="{href}" style="color:{_HEX};">{escape(link)}</a></p>
          </td>
        </tr>
        <tr>
          <td style="padding:20px 32px 28px;font-family:Georgia,serif;font-size:12px;line-height:1.5;color:{_MUTED};">
            <hr style="border:0;border-top:1px solid rgba(138,106,47,0.28);margin:0 0 16px;">
            Projet fan-made à but non lucratif, non affilié à Riot Games.<br>
            <a href="{escape(settings.base_url, quote=True)}" style="color:{_GOLD_DEEP};text-decoration:none;">{escape(settings.base_url.replace("https://", "").replace("http://", ""))}</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
"""


def _build_message(to: str, subject: str, text: str, html: str | None = None) -> EmailMessage:
    message = EmailMessage()
    message["From"] = settings.mail_from
    message["To"] = to
    message["Subject"] = subject
    message["Date"] = formatdate(localtime=False)
    message["Message-ID"] = make_msgid(domain=_from_domain())
    message.set_content(text, charset="utf-8")
    if html:
        message.add_alternative(html, subtype="html", charset="utf-8")
    return message


def _deliver(smtp: smtplib.SMTP, message: EmailMessage) -> None:
    if settings.smtp_user:
        smtp.login(settings.smtp_user, settings.smtp_password)
    smtp.send_message(message)


def send_email(to: str, subject: str, body: str, html: str | None = None) -> None:
    """Envoie un e-mail UTF-8 (texte, plus HTML si fourni). Ne lève jamais : l'échec est loggé.

    Appelé en tâche de fond pour ne pas bloquer la requête HTTP.
    """
    if not settings.smtp_host:
        log.info("mode console — e-mail pour %s : %s\n%s", to, subject, body)
        return
    try:
        message = _build_message(to, subject, body, html)
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


def _send_copy(to: str, copy: MailCopy, link: str) -> None:
    send_email(to, copy.subject, _plain(copy, link), html=_html(copy, link))


def send_verification_email(to: str, token: str) -> None:
    link = f"{settings.base_url}/verification-email?token={token}"
    _send_copy(to, _VERIFY, link)


def send_reset_email(to: str, token: str) -> None:
    link = f"{settings.base_url}/reinitialisation?token={token}"
    _send_copy(to, _RESET, link)


NOTIFY_OPT_OUT = "Vous pouvez désactiver ces notifications depuis votre profil."


def _moderation_copy(deck_name: str, approved: bool) -> MailCopy:
    """Contenu de la notification de modération : approbation, ou rejet bienveillant.

    Le rejet ne détaille pas le motif : il rappelle simplement que le deck peut
    être modifié puis proposé à nouveau.
    """
    if approved:
        return MailCopy(
            subject=f"Votre deck “{deck_name}” est publié — Riftarium",
            preheader="Votre deck a été approuvé : il est visible par toute la communauté.",
            title="Votre deck est publié",
            paragraphs=(
                f"Bonne nouvelle : votre deck « {deck_name} » vient d'être approuvé par la modération.",
                "Il est désormais visible par toute la communauté Riftarium.",
            ),
            cta="Voir mon deck",
            validity="",
            ignore=NOTIFY_OPT_OUT,
        )
    return MailCopy(
        subject=f"Votre deck “{deck_name}” n'a pas été retenu — Riftarium",
        preheader="Votre deck reste privé pour le moment : il peut être modifié et proposé à nouveau.",
        title="Votre deck n'a pas été retenu",
        paragraphs=(
            f"Après relecture, votre deck « {deck_name} » n'a pas été retenu par la modération cette fois-ci.",
            "Rien d'irréversible : vous pouvez le modifier puis le proposer à nouveau quand vous le souhaitez.",
        ),
        cta="Modifier mon deck",
        validity="",
        ignore=NOTIFY_OPT_OUT,
    )


def send_moderation_email(to: str, deck_name: str, deck_id: int, approved: bool) -> None:
    link = f"{settings.base_url}/decks/{deck_id}"
    _send_copy(to, _moderation_copy(deck_name, approved), link)


def send_moderation_email_async(to: str, deck_name: str, deck_id: int, approved: bool) -> threading.Thread | None:
    """Envoi de la notification de modération dans un thread dédié (fire-and-forget).

    apply_deck_moderation est aussi appelable hors contexte requête (chemin
    X-Admin-Token, scripts) : pas de BackgroundTasks sous la main, donc un
    thread daemon. Jamais bloquant : tout échec est loggé, jamais propagé
    (send_moderation_email ne lève déjà jamais). Le thread est renvoyé pour
    permettre aux tests de l'attendre.
    """
    try:
        thread = threading.Thread(
            target=send_moderation_email,
            args=(to, deck_name, deck_id, approved),
            name=f"mail-moderation-deck-{deck_id}",
            daemon=True,
        )
        thread.start()
    except Exception:
        log.exception("impossible de lancer l'envoi de la notification de modération vers %s", to)
        return None
    return thread
