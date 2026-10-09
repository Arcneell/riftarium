"""E-mails transactionnels : vérification d'adresse, réinitialisation de mot de
passe et notifications de modération des decks.

SMTP_HOST vide → « mode console » : le message est loggé au lieu d'être envoyé
(c'est le mode développement). Sinon, envoi via SMTP OVH : SSL implicite sur le
port 465, STARTTLS sur les autres ports (587). Les fonctions sont appelées en
tâche de fond (BackgroundTasks, ou thread dédié hors contexte requête) : un
échec SMTP est loggé mais ne fait jamais échouer la requête HTTP (robustesse +
anti-énumération des comptes).

Chaque envoi est multipart (texte + HTML) : le HTML reprend la charte « Forge
noxienne » du site ; le texte brut reste lisible si le client masque les images.
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

# Couleurs de la charte « Forge noxienne » (apps/web/src/styles/tokens.css).
_BG = "#0d0d0f"  # noir de forge : fond autour du message
_RAISED = "#17120f"  # panneau du message
_LINE = "#2f2721"
_BLOOD = "#b3262b"  # liseré et bouton d'action
_BLOOD_TEXT = "#e0605a"  # liens dans le texte
_BRONZE = "#8a6e4b"
_BRONZE_LIGHT = "#d6b98c"  # intertitres, marque
_INK = "#e9e2d8"
_MUTED = "#9a8f80"
# Les clients mail ne chargent pas Cinzel / Barlow : repli sur des polices système proches.
_DISPLAY = "Georgia,'Times New Roman',serif"
_BODY = "'Segoe UI',Helvetica,Arial,sans-serif"


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
        "Votre compte est créé : base de cartes, collection et création de decks vous attendent.",
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
    # PNG et non SVG : Gmail et Outlook bloquent les images SVG.
    return f"{settings.base_url}/icon-192.png"


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
        f'<p style="margin:0 0 14px;font-family:{_BODY};font-size:16px;line-height:1.6;color:{_INK};">'
        f"{escape(paragraph)}</p>"
        for paragraph in copy.paragraphs
    )
    site = escape(settings.base_url, quote=True)
    domain = escape(settings.base_url.replace("https://", "").replace("http://", ""))
    # Charte Forge : fond noir, panneau brun très sombre, liseré rouge sang en tête,
    # filets de bronze, bouton rouge aux angles vifs (pas d'arrondi), titres en capitales.
    return f"""\
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark">
<meta name="supported-color-schemes" content="dark">
<title>{escape(copy.subject)}</title>
</head>
<body style="margin:0;padding:0;background:{_BG};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">{escape(copy.preheader)}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="{_BG}" style="background:{_BG};">
  <tr>
    <td align="center" style="padding:28px 12px;">
      <table role="presentation" width="600" cellspacing="0" cellpadding="0" bgcolor="{_RAISED}" style="width:600px;max-width:100%;background:{_RAISED};border:1px solid {_LINE};">
        <tr><td bgcolor="{_BLOOD}" style="height:4px;background:{_BLOOD};font-size:0;line-height:0;">&nbsp;</td></tr>
        <tr>
          <td align="center" style="padding:28px 32px 18px;">
            <img src="{logo}" width="64" height="64" alt="Riftarium" style="display:block;border:0;width:64px;height:64px;">
            <p style="margin:14px 0 0;font-family:{_DISPLAY};font-size:22px;font-weight:bold;letter-spacing:0.16em;color:{_INK};">RIFTARIUM</p>
            <p style="margin:6px 0 0;font-family:{_BODY};font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:{_BRONZE_LIGHT};">Le compagnon Riftbound</p>
          </td>
        </tr>
        <tr>
          <td style="padding:0 32px;">
            <hr style="border:0;border-top:1px solid {_BRONZE};margin:0;opacity:0.6;">
          </td>
        </tr>
        <tr>
          <td style="padding:28px 32px 8px;">
            <h1 style="margin:0 0 18px;font-family:{_DISPLAY};font-size:24px;line-height:1.25;font-weight:bold;letter-spacing:0.04em;text-transform:uppercase;color:{_BRONZE_LIGHT};">{escape(copy.title)}</h1>
            {paragraphs}
            <table role="presentation" cellspacing="0" cellpadding="0" style="margin:24px 0 8px;">
              <tr>
                <td align="center" bgcolor="{_BLOOD}" style="background:{_BLOOD};">
                  <a href="{href}" style="display:inline-block;padding:14px 28px;font-family:{_BODY};font-size:15px;font-weight:bold;letter-spacing:0.12em;text-transform:uppercase;color:#ffffff;text-decoration:none;">{escape(copy.cta)}</a>
                </td>
              </tr>
            </table>
            <p style="margin:18px 0 0;font-family:{_BODY};font-size:13px;line-height:1.5;color:{_MUTED};">{escape(_footer_note(copy))}</p>
            <p style="margin:16px 0 0;font-family:{_BODY};font-size:12px;line-height:1.5;color:{_MUTED};word-break:break-all;">Si le bouton ne fonctionne pas, copiez ce lien dans votre navigateur :<br><a href="{href}" style="color:{_BLOOD_TEXT};">{escape(link)}</a></p>
          </td>
        </tr>
        <tr>
          <td style="padding:20px 32px 28px;font-family:{_BODY};font-size:12px;line-height:1.5;color:{_MUTED};">
            <hr style="border:0;border-top:1px solid {_LINE};margin:0 0 16px;">
            Projet de fan à but non lucratif, non affilié à Riot Games.<br>
            <a href="{site}" style="color:{_BRONZE_LIGHT};text-decoration:none;">{domain}</a>
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


# ---------- Échanges entre joueurs (docs/echanges.md) ----------
# Le contact externe de l'autre joueur n'apparaît jamais dans un e-mail : il ne
# se lit que sur le site, une fois la demande acceptée.


def _trade_link(request_id: int) -> str:
    return f"{settings.base_url}/echanges?onglet=demandes&id={request_id}"


def _trade_request_copy(handle: str, card_name: str, message: str) -> MailCopy:
    paragraphs = [f"{handle} est intéressé par votre carte « {card_name} » proposée à l'échange."]
    if message:
        paragraphs.append(f"Son message : « {message} »")
    paragraphs.append("Acceptez la demande pour que chacun voie le contact de l'autre, ou refusez-la.")
    return MailCopy(
        subject=f"{handle} est intéressé par votre carte “{card_name}” — Riftarium",
        preheader=f"Nouvelle demande d'échange pour « {card_name} ».",
        title="Nouvelle demande d'échange",
        paragraphs=tuple(paragraphs),
        cta="Voir la demande",
        validity="",
        ignore=NOTIFY_OPT_OUT,
    )


def _trade_accepted_copy(handle: str, card_name: str) -> MailCopy:
    return MailCopy(
        subject=f"{handle} a accepté votre demande pour “{card_name}” — Riftarium",
        preheader="Votre demande d'échange est acceptée : son contact vous attend sur le site.",
        title="Demande acceptée",
        paragraphs=(
            f"Bonne nouvelle : {handle} a accepté votre demande pour « {card_name} ».",
            "Son contact est visible sur la page Échanges de Riftarium : à vous de convenir de l'échange.",
        ),
        cta="Voir son contact",
        validity="",
        ignore=NOTIFY_OPT_OUT,
    )


def send_trade_request_email(to: str, handle: str, card_name: str, message: str, request_id: int) -> None:
    _send_copy(to, _trade_request_copy(handle, card_name, message), _trade_link(request_id))


def send_trade_accepted_email(to: str, handle: str, card_name: str, request_id: int) -> None:
    _send_copy(to, _trade_accepted_copy(handle, card_name), _trade_link(request_id))
