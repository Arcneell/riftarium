<script setup>
import { computed, ref } from "vue"
import { useRoute } from "vue-router"
import {
  CONTACT_EMAIL,
  CONTACT_MAILTO,
  GITHUB_ISSUES,
  GITHUB_REPO,
  HOST,
  LEGAL_NAV,
  LEGAL_UPDATED,
  RIOT_DISCLAIMER_EN,
  RIOT_DISCLAIMER_FR,
  RIOT_GENERAL_DISCLAIMER_EN,
  RIOT_GENERAL_DISCLAIMER_FR,
  RIOT_LEGAL,
  RIOT_RIFTBOUND_POLICY,
  RIFTBOUND_OFFICIAL,
  RIFTCODEX
} from "../legal.js"
import { useBreakpoint } from "../composables/useBreakpoint.js"

const TITLES = {
  mentions: { title: "Mentions légales" },
  privacy: { title: "Politique de confidentialité" },
  terms: { title: "Conditions d'utilisation" },
  cookies: { title: "Cookies et traceurs" },
  report: { title: "Signaler un contenu" }
}

/* Sommaire de chaque page : les identifiants sont les ancres des titres h2 ci-dessous. */
const SECTIONS = {
  mentions: [
    { id: "editeur", label: "Éditeur" },
    { id: "hebergement", label: "Hébergement" },
    { id: "propriete-intellectuelle", label: "Propriété intellectuelle de Riot Games" },
    { id: "code-source", label: "Code source" }
  ],
  privacy: [
    { id: "responsable", label: "Responsable de traitement" },
    { id: "donnees", label: "Données traitées" },
    { id: "finalites", label: "Finalités et bases" },
    { id: "durees", label: "Durées de conservation" },
    { id: "destinataires", label: "Destinataires et sous-traitants techniques" },
    { id: "droits", label: "Vos droits" },
    { id: "age", label: "Âge" }
  ],
  terms: [
    { id: "objet", label: "Objet" },
    { id: "compte", label: "Compte" },
    { id: "formats", label: "Formats de decks" },
    { id: "contenus", label: "Contenus publiés" },
    { id: "donnees-cartes", label: "Données de cartes et de règles" },
    { id: "parties", label: "Parties suivies" },
    { id: "profils", label: "Profils publics et abonnements" },
    { id: "echanges", label: "Échanges entre joueurs" },
    { id: "disponibilite", label: "Disponibilité" },
    { id: "droit", label: "Droit applicable" }
  ],
  cookies: [
    { id: "consentement", label: "Pourquoi aucun consentement n'est demandé" },
    { id: "stockage", label: "Stockage strictement nécessaire" },
    { id: "traitement", label: "Mesures sans cookie" },
    { id: "tiers", label: "Tiers au chargement des pages" }
  ],
  report: [
    { id: "pourquoi", label: "Pourquoi signaler" },
    { id: "comment", label: "Comment faire" }
  ]
}

const route = useRoute()
const breakpoint = useBreakpoint()
const page = computed(() => route.meta.legal || "mentions")
const copy = computed(() => TITLES[page.value] || TITLES.mentions)
const sections = computed(() => SECTIONS[page.value] || SECTIONS.mentions)

/* Section courante du sommaire : celle de l'ancre d'arrivée (sans le #), vide sinon ; puis celle qu'on active.
   La vue est remontée à chaque changement de chemin : pas de suivi des pages ici. */
const activeId = ref(route.hash.replace(/^#/, ""))
const toc = ref(null)

function pick(id) {
  activeId.value = id
  /* sous 1 024 px, le sommaire se referme une fois la section choisie */
  if (toc.value && "open" in toc.value) toc.value.open = false
}
</script>

<template>
  <div class="wrap mentions-page">
    <header class="mentions-head">
      <h1 class="mentions-titre">{{ copy.title }}</h1>
      <p class="mentions-maj">Mise à jour : {{ LEGAL_UPDATED }}</p>
    </header>

    <div class="mentions-layout">
      <component :is="breakpoint === 'desktop' ? 'aside' : 'details'" ref="toc" class="mentions-toc">
        <summary v-if="breakpoint !== 'desktop'" class="mentions-toc-summary">Sommaire</summary>
        <nav aria-label="Pages légales">
          <p class="mentions-toc-titre">Pages légales</p>
          <RouterLink v-for="item in LEGAL_NAV" :key="item.key" class="mentions-toc-link" :to="item.path">{{
            item.label
          }}</RouterLink>
        </nav>
        <nav aria-label="Sur cette page">
          <p class="mentions-toc-titre">Sur cette page</p>
          <a
            v-for="item in sections"
            :key="item.id"
            class="mentions-toc-link"
            :href="'#' + item.id"
            :aria-current="item.id === activeId ? 'location' : undefined"
            @click="pick(item.id)"
            >{{ item.label }}</a
          >
        </nav>
      </component>

      <article class="mentions-doc">
        <template v-if="page === 'mentions'">
          <h2 id="editeur">Éditeur</h2>
          <p>
            Riftarium est un site communautaire édité à titre non professionnel, bénévole et non commercial, par
            l'auteur du dépôt
            <a :href="GITHUB_REPO" target="_blank" rel="noopener">github.com/Arcneell/riftarium</a>
            (pseudonyme Arcneell). Le site est actuellement en <strong>bêta fermée</strong> : il n'est pas annoncé
            publiquement et n'est pas indexé par les moteurs de recherche.
          </p>
          <p>
            Contact :
            <a :href="CONTACT_MAILTO">{{ CONTACT_EMAIL }}</a
            >. Pour un bug technique : les <a :href="GITHUB_ISSUES" target="_blank" rel="noopener">tickets GitHub</a>.
          </p>

          <h2 id="hebergement">Hébergement</h2>
          <p>
            Le site est hébergé par {{ HOST.name }}, {{ HOST.form }}, {{ HOST.address }}. {{ HOST.rcs }}. TVA :
            {{ HOST.tva }}. Tél. {{ HOST.phone }}. <a :href="HOST.site" target="_blank" rel="noopener">ovhcloud.com</a>.
          </p>
          <p>
            Les illustrations de cartes et bannières sont servies par le CDN de Riot Games, Inc., sans copie ni
            redistribution locale. Les polices d'écriture sont hébergées sur le même serveur que le site.
          </p>

          <h2 id="propriete-intellectuelle">Propriété intellectuelle de Riot Games</h2>
          <p class="mentions-quote">{{ RIOT_DISCLAIMER_EN }}</p>
          <p>{{ RIOT_DISCLAIMER_FR }}</p>
          <p class="mentions-quote">{{ RIOT_GENERAL_DISCLAIMER_EN }}</p>
          <p>{{ RIOT_GENERAL_DISCLAIMER_FR }}</p>
          <p>
            Riftbound, League of Legends, les visuels de cartes, illustrations, glyphes, textes de cartes et documents
            de règles sont la propriété de © Riot Games, Inc. Riftarium n'est ni affilié, ni soutenu, ni sponsorisé par
            Riot Games. Politiques :
            <a :href="RIOT_LEGAL" target="_blank" rel="noopener">Legal Jibber Jabber</a>
            et
            <a :href="RIOT_RIFTBOUND_POLICY" target="_blank" rel="noopener">politique développeur Riftbound</a>. Site
            officiel : <a :href="RIFTBOUND_OFFICIAL" target="_blank" rel="noopener">playriftbound.com</a>.
          </p>
          <p>
            En bêta, les métadonnées de cartes (noms, textes, classifications) sont synchronisées depuis l'API
            communautaire
            <a :href="RIFTCODEX" target="_blank" rel="noopener">Riftcodex</a>
            en attendant l'accès à l'API officielle Riot. Les visuels restent ceux du CDN officiel Riot.
          </p>
          <p>
            Les prix de cartes affichés proviennent du marché américain (TCGplayer), convertis en euros au taux de la
            Banque centrale européenne : ce sont des estimations indicatives, qui ne constituent ni une cote officielle
            ni une offre d'achat.
          </p>

          <h2 id="code-source">Code source</h2>
          <p>
            Le code de Riftarium est consultable sur GitHub sous licence « source accessible » : lecture et
            contributions, pas de copie ni de redéploiement sans autorisation. Cette licence ne couvre aucun actif Riot.
          </p>
        </template>

        <template v-else-if="page === 'privacy'">
          <h2 id="responsable">Responsable de traitement</h2>
          <p>
            L'éditeur de Riftarium (voir
            <RouterLink to="/mentions-legales">mentions légales</RouterLink>) est responsable des traitements décrits
            ici.
          </p>

          <h2 id="donnees">Données traitées</h2>
          <ul>
            <li>
              <strong>Compte</strong> : pseudo, adresse e-mail, mot de passe haché (scrypt), biographie, avatar choisi
              parmi les légendes officielles (URL d'image Riot, jamais recopiée).
            </li>
            <li>
              <strong>Collection et decks</strong> : cartes, quantités, état, langue, listes de decks, descriptions,
              visibilité publique ou privée.
            </li>
            <li>
              <strong>Communauté</strong> : mentions « J'aime », compteur de vues uniques. Pour un visiteur non
              connecté, un hash SHA-256 tronqué de l'adresse IP est stocké afin de ne compter qu'une visite par personne
              et par deck. Ce hash n'est pas reversé en adresse IP dans l'interface.
            </li>
            <li>
              <strong>Parties suivies</strong> : salons (code, format, joueurs), pour chaque match la légende et le deck
              choisis, le score, les manches gagnées, le vainqueur, la confirmation ou la contestation du résultat, les
              dates. Votre adversaire voit votre pseudo, votre avatar, votre légende, votre deck et le score.
              L'historique et les statistiques en sont calculés.
            </li>
            <li>
              <strong>Profil public et abonnements</strong> : vos réglages de confidentialité (statistiques, collection,
              decks, hauts faits), vos hauts faits débloqués et leur date, les joueurs que vous suivez et ceux qui vous
              suivent.
            </li>
            <li>
              <strong>Échanges</strong> : activation, zone, contact libre (par exemple un pseudo Discord), préférence de
              notification, cartes proposées (« À échanger »), demandes envoyées et reçues avec leur message et leur
              statut. Votre contact n'est montré qu'à l'autre partie d'une demande acceptée, jamais dans un e-mail. Les
              joueurs ayant activé les échanges voient votre pseudo, votre avatar, votre zone et vos offres.
            </li>
            <li>
              <strong>Session</strong> : un cookie HTTP-only <code>riftarium_session</code> (jeton JWT, 24 heures,
              renouvelé à la connexion). Le navigateur ne peut pas le lire en JavaScript.
            </li>
          </ul>

          <h2 id="finalites">Finalités et bases</h2>
          <ul>
            <li>Fournir le compte, la collection et le deck builder : exécution du service demandé.</li>
            <li>
              Publier les decks que vous rendez publics : exécution du service, ou intérêt légitime de la communauté.
            </li>
            <li>
              Suivre les parties, tenir l'historique, les statistiques et les hauts faits, afficher le profil public et
              les abonnements selon vos réglages : exécution du service demandé.
            </li>
            <li>
              Mettre en relation les joueurs qui ont activé les échanges, dévoiler le contact après acceptation et
              envoyer les e-mails de notification que vous n'avez pas désactivés : exécution du service demandé.
            </li>
            <li>Compter les vues uniques : intérêt légitime (statistique d'audience d'un deck, pas de publicité).</li>
            <li>Modérer les textes publiés : intérêt légitime et obligation de limiter les abus.</li>
            <li>Sécurité du compte (mot de passe, jeton) : intérêt légitime.</li>
          </ul>
          <p>Aucune donnée n'est vendue. Pas de publicité ni de profilage commercial.</p>

          <h2 id="durees">Durées de conservation</h2>
          <ul>
            <li>
              Compte, collection, decks : jusqu'à suppression du compte par vos soins, ou suppression par l'éditeur.
            </li>
            <li>
              Hauts faits, abonnements, réglages d'échange, offres et demandes d'échange : jusqu'à la suppression de
              votre compte. Un abonnement ou une demande d'échange disparaît aussi quand l'autre compte est supprimé.
            </li>
            <li>
              Parties suivies : vos participations sont supprimées avec votre compte. Le match reste dans l'historique
              et les statistiques de votre adversaire, sans lien vers votre compte.
            </li>
            <li>Jeton de session : 24 heures, ou jusqu'à déconnexion (révocation immédiate du cookie).</li>
            <li>
              Hash d'IP des vues : tant que le deck public existe. Il est effacé avec le deck ou, pour un compte, à la
              suppression de ce compte.
            </li>
          </ul>

          <h2 id="destinataires">Destinataires et sous-traitants techniques</h2>
          <ul>
            <li>{{ HOST.name }} (hébergement de l'application et de la base), {{ HOST.address }}.</li>
            <li>
              Riot Games, via son CDN : votre navigateur charge les illustrations. Riot peut à ce titre recevoir
              l'adresse IP technique de la requête d'image.
            </li>
            <li>
              Riftcodex : interrogé uniquement par le serveur, pour le catalogue de cartes. Pas de données de compte
              transmises.
            </li>
          </ul>

          <h2 id="droits">Vos droits</h2>
          <p>
            Vous pouvez accéder à vos données, les rectifier, les exporter et supprimer votre compte depuis
            <RouterLink to="/profil">Mon profil</RouterLink>
            (export JSON et suppression définitive, mot de passe exigé). Pour toute autre demande :
            <a :href="CONTACT_MAILTO">{{ CONTACT_EMAIL }}</a>
            ou la page
            <RouterLink to="/signalement">Signalement</RouterLink>.
          </p>
          <p>
            Vous pouvez aussi introduire une réclamation auprès de la
            <a href="https://www.cnil.fr" target="_blank" rel="noopener">CNIL</a>.
          </p>

          <h2 id="age">Âge</h2>
          <p>
            Le service n'est pas destiné aux moins de 15 ans (âge du consentement numérique en France). L'inscription
            exige de le confirmer.
          </p>
        </template>

        <template v-else-if="page === 'terms'">
          <h2 id="objet">Objet</h2>
          <p>
            Riftarium est un compagnon gratuit, fait par un fan, pour le jeu de cartes Riftbound : cartothèque, règles,
            collection personnelle, wishlist, deck builder et partage de decks, suivi de parties entre joueurs, profils
            publics et mise en relation pour des échanges de cartes. C'est un projet en <strong>bêta fermée</strong>,
            indépendant de Riot Games, non annoncé publiquement.
          </p>
          <p class="mentions-quote">{{ RIOT_DISCLAIMER_EN }}</p>
          <p>{{ RIOT_DISCLAIMER_FR }}</p>
          <p class="mentions-quote">{{ RIOT_GENERAL_DISCLAIMER_EN }}</p>
          <p>{{ RIOT_GENERAL_DISCLAIMER_FR }}</p>

          <h2 id="compte">Compte</h2>
          <p>
            L'inscription est réservée aux personnes d'au moins 15 ans. Vous êtes responsable de la confidentialité de
            votre mot de passe et des contenus que vous publiez (pseudo, bio, decks, descriptions).
          </p>

          <h2 id="formats">Formats de decks</h2>
          <ul>
            <li>
              <strong>Légal</strong> : le site vérifie les règles officielles de construction (légende, champs de
              bataille, runes, taille, exemplaires, domaines, champion élu).
            </li>
            <li>
              <strong>Illégal</strong> : deck libre, <strong>format non officiel</strong>. Il n'applique pas les
              contraintes de tournoi et ne correspond à aucun format Riot.
            </li>
          </ul>

          <h2 id="contenus">Contenus publiés</h2>
          <p>
            En rendant un deck public ou en remplissant une bio, vous autorisez Riftarium à l'afficher aux visiteurs du
            site, uniquement pour le fonctionnement du service. Vous gardez la responsabilité de vos textes. Un filtre
            automatique peut retenir un contenu ; l'éditeur peut le dépublier ou supprimer un compte en cas d'abus.
          </p>
          <p>
            Ces règles valent aussi pour les messages joints aux demandes d'échange et pour le contact d'échange.
            Interdit notamment : insultes, harcèlement, incitation à la haine, spam, arnaques, vente hors cadre,
            usurpation, contenu illégal.
          </p>

          <h2 id="donnees-cartes">Données de cartes et de règles</h2>
          <p>
            Les cartes et règles reproduites restent la propriété de Riot Games. En cas d'écart, les documents et
            traductions officiels font foi. Le site n'est pas un client de jeu : aucune partie n'y est simulée.
          </p>

          <h2 id="parties">Parties suivies</h2>
          <p>
            Deux joueurs inscrits peuvent suivre une partie réelle dans un salon. Les joueurs saisissent eux-mêmes les
            points, l'XP et les tours ; le site ne résout aucune règle. Le résultat, envoyé par l'hôte, ne compte dans
            l'historique, les statistiques (victoires, défaites, taux de victoire, séries) et les hauts faits que s'il
            est confirmé par les deux joueurs. Un résultat contesté n'est pas compté. Un abandon compte comme une
            défaite pour celui qui abandonne. La partie libre, sans compte, n'est pas enregistrée.
          </p>
          <p>
            Le site ne publie aucun classement général des joueurs. Vos statistiques de parties suivies et vos hauts
            faits peuvent apparaître sur votre profil public, selon vos réglages de confidentialité.
          </p>

          <h2 id="profils">Profils publics et abonnements</h2>
          <p>
            Chaque compte a un profil public : pseudo, avatar, bio, date d'inscription, nombre d'abonnés et
            d'abonnements. Depuis votre profil, vous choisissez d'y montrer ou non vos statistiques, votre collection,
            vos decks publics et vos hauts faits. Vous pouvez suivre d'autres joueurs pour les retrouver et les inviter
            dans un salon. Il n'y a pas de messagerie.
          </p>

          <h2 id="echanges">Échanges entre joueurs</h2>
          <p>
            Les échanges sont désactivés par défaut. Pour les activer, vous indiquez une zone et un contact. Riftarium
            montre alors les cartes que vous proposez aux autres joueurs qui ont aussi activé les échanges, et vous
            montre les leurs. Une demande porte sur une offre ; si elle est acceptée, chacune des deux parties voit le
            contact de l'autre.
          </p>
          <p>
            Riftarium se limite à la mise en relation : aucun prix affiché, aucun paiement, aucune commission. L'échange
            se règle entre joueurs, hors du site, et chacun reste responsable de ce qu'il convient.
          </p>

          <h2 id="disponibilite">Disponibilité</h2>
          <p>
            Le service est fourni « en l'état », sans garantie de disponibilité ni d'exactitude des données pendant la
            bêta. L'éditeur peut modifier, suspendre ou arrêter le site, notamment si Riot le demande.
          </p>

          <h2 id="droit">Droit applicable</h2>
          <p>Les présentes sont soumises au droit français. Tout litige relève des tribunaux compétents en France.</p>
        </template>

        <template v-else-if="page === 'cookies'">
          <h2 id="consentement">Pourquoi aucun consentement n'est demandé</h2>
          <p>
            La CNIL n'exige un bandeau de consentement que pour les traceurs non nécessaires (publicité, réseaux
            sociaux, mesure d'audience). Riftarium n'en dépose aucun. Un bandeau d'information s'affiche à la première
            visite pour l'expliquer ; il n'y a rien à « accepter » au-delà de cette information.
          </p>

          <h2 id="stockage">Stockage strictement nécessaire</h2>
          <ul>
            <li>
              <strong>cookie HTTP-only</strong> (<code>riftarium_session</code>) : jeton de session, inaccessible au
              JavaScript. Durée : 24 heures, ou jusqu'à déconnexion.
            </li>
            <li>
              <strong>localStorage</strong> (<code>riftarium_session</code>, pseudo, avatar) : simple indicateur
              d'interface pour afficher le compte connecté, sans le jeton.
            </li>
            <li>
              <strong>localStorage</strong> (<code>riftarium_traceurs_ack</code>) : mémorise que le bandeau
              d'information a été lu, pour ne pas le réafficher.
            </li>
          </ul>

          <h2 id="traitement">Mesures sans cookie</h2>
          <p>
            Les vues de decks publics dédupliquent les visiteurs anonymes via un hash d'adresse IP côté serveur. Voir la
            <RouterLink to="/confidentialite">politique de confidentialité</RouterLink>.
          </p>
          <p>
            Riftarium compte également ses visites de façon agrégée, par jour et par rubrique (accueil, cartes,
            règles…), sans aucune donnée personnelle ni cookie : une empreinte technique salée, non conservée au-delà de
            48 heures, sert uniquement à dédupliquer les visiteurs du jour.
          </p>

          <h2 id="tiers">Tiers au chargement des pages</h2>
          <ul>
            <li>Illustrations : CDN Riot Games. Requête technique d'image, pas un cookie déposé par Riftarium.</li>
            <li>Polices : servies par Riftarium, pas par Google Fonts.</li>
          </ul>
        </template>

        <template v-else>
          <h2 id="pourquoi">Pourquoi signaler</h2>
          <p>
            Riftarium héberge des textes d'utilisateurs (bios, noms et descriptions de decks, messages et contacts
            d'échange). Si un contenu est illicite, contraire aux
            <RouterLink to="/cgu">CGU</RouterLink>, ou porte atteinte à un droit, signalez-le.
          </p>

          <h2 id="comment">Comment faire</h2>
          <p>
            Écrivez à
            <a :href="CONTACT_MAILTO">{{ CONTACT_EMAIL }}</a>
            en indiquant :
          </p>
          <ul>
            <li>l'URL de la page ou le nom du deck / le pseudo concerné ;</li>
            <li>une description précise du problème ;</li>
            <li>un moyen de vous recontacter si ce n'est pas l'adresse d'envoi.</li>
          </ul>
          <p>
            Pour un bug technique sans enjeu légal, un
            <a :href="GITHUB_ISSUES" target="_blank" rel="noopener">ticket GitHub</a>
            suffit.
          </p>
        </template>
      </article>
    </div>
  </div>
</template>

<style scoped>
.mentions-page {
  padding-top: var(--space-6);
  padding-bottom: var(--space-7);
}
.mentions-head {
  margin-bottom: var(--space-5);
}
.mentions-page .mentions-titre {
  margin: 0 0 var(--space-2);
  color: var(--ink);
  font-family: var(--font-display);
  font-size: clamp(1.8rem, 4vw, 2.6rem);
  font-weight: 700;
}
.mentions-maj {
  margin: 0;
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 15px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}
.mentions-layout {
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  gap: var(--space-6);
  align-items: start;
}
.mentions-toc {
  position: sticky;
  top: calc(var(--topbar-h) + var(--space-4));
  max-height: calc(100dvh - var(--topbar-h) - 32px);
  overflow-y: auto;
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.mentions-toc nav {
  display: flex;
  flex-direction: column;
}
.mentions-toc nav + nav {
  margin-top: var(--space-4);
}
.mentions-toc-titre {
  margin: 0 0 var(--space-2);
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
.mentions-toc-link {
  display: flex;
  align-items: center;
  min-height: 44px;
  padding: var(--space-2);
  border-left: 2px solid transparent;
  color: var(--ink);
  font-family: var(--font-body);
  font-size: 15px;
  line-height: 1.3;
  text-decoration: none;
  transition:
    background var(--t-fast),
    border-color var(--t-fast);
}
.mentions-toc-link:hover {
  background: var(--bg-sunken);
}
.mentions-toc-link[aria-current] {
  background: var(--bg-sunken);
  border-left-color: var(--blood);
  color: var(--bronze-light);
}
.mentions-toc-link:focus-visible,
.mentions-toc-summary:focus-visible,
.mentions-doc a:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -3px;
}
.mentions-toc-summary {
  display: flex;
  align-items: center;
  min-height: 44px;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 16px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  cursor: pointer;
}

/* Typographie de lecture */
.mentions-doc {
  min-width: 0;
  max-width: 760px;
  color: var(--ink);
  font-family: var(--font-body);
  font-size: 17px;
  line-height: 1.65;
}
.mentions-doc h2 {
  margin: var(--space-6) 0 var(--space-3);
  padding: 0;
  scroll-margin-top: calc(var(--topbar-h) + var(--space-4));
  color: var(--bronze-light);
  font-family: var(--font-display);
  font-size: 1.35rem;
  font-weight: 700;
  line-height: 1.25;
}
.mentions-doc h2:first-child {
  margin-top: 0;
}
.mentions-doc p,
.mentions-doc li {
  margin: 0 0 var(--space-3);
  line-height: 1.65;
}
.mentions-doc ul {
  margin: 0 0 var(--space-3);
  padding-left: 1.3em;
}
.mentions-doc a {
  color: var(--blood-text);
  text-underline-offset: 3px;
}
.mentions-doc a:hover {
  color: var(--bronze-light);
}
.mentions-doc code {
  font-family: ui-monospace, monospace;
  font-size: 0.9em;
}
.mentions-quote {
  padding: var(--space-3) var(--space-4);
  border-left: 3px solid var(--bronze);
  background: var(--bg-raised);
  color: var(--ink-muted);
  font-style: italic;
}
@media (max-width: 1023px) {
  .mentions-layout {
    grid-template-columns: 1fr;
    gap: var(--space-4);
  }
  .mentions-toc {
    position: static;
  }
}
@media (prefers-reduced-motion: reduce) {
  .mentions-toc-link {
    transition: none;
  }
}
</style>
