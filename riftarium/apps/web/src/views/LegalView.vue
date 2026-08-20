<script setup>
import { computed } from "vue"
import { useRoute } from "vue-router"
import { BANNERS } from "../banners.js"
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
import PageBanner from "../components/PageBanner.vue"

const TITLES = {
  mentions: {
    title: "Mentions légales",
    lead: "Qui édite Riftarium, comment nous joindre, où sont hébergées les pages."
  },
  privacy: {
    title: "Politique de confidentialité",
    lead: "Quelles données le site traite, pourquoi, combien de temps, et quels droits vous avez."
  },
  terms: {
    title: "Conditions d'utilisation",
    lead: "Les règles du service : comptes, decks publics, modération, responsabilité."
  },
  cookies: {
    title: "Cookies et traceurs",
    lead: "Ce que le site stocke sur votre appareil, et ce qu'il ne stocke pas."
  },
  report: {
    title: "Signaler un contenu",
    lead: "Comment nous prévenir d'un contenu illicite, abusif ou qui viole les conditions."
  }
}

const route = useRoute()
const page = computed(() => route.meta.legal || "mentions")
const copy = computed(() => TITLES[page.value] || TITLES.mentions)
</script>

<template>
  <PageBanner :art="BANNERS.rules" eyebrow="Informations légales" :title="copy.title">
    {{ copy.lead }}
  </PageBanner>

  <section class="legal-page">
    <div class="wrap legal-layout">
      <nav class="legal-nav" aria-label="Pages légales">
        <RouterLink v-for="item in LEGAL_NAV" :key="item.key" :to="item.path">{{ item.label }}</RouterLink>
      </nav>

      <article class="legal-doc panel">
        <p class="muted mono legal-updated">Mise à jour : {{ LEGAL_UPDATED }}</p>

        <template v-if="page === 'mentions'">
          <h3>Éditeur</h3>
          <p>
            Riftarium est un site communautaire édité à titre non professionnel, bénévole et non commercial, par
            l'auteur du dépôt
            <a :href="GITHUB_REPO" target="_blank" rel="noopener">github.com/Arcneell/riftarium</a>
            (pseudonyme Arcneell). Le site est actuellement en <strong>bêta fermée</strong> : il n'est pas annoncé
            publiquement et n'est pas indexé par les moteurs de recherche.
          </p>
          <p>
            Contact :
            <a :href="CONTACT_MAILTO">{{ CONTACT_EMAIL }}</a>
            — bugs techniques via les
            <a :href="GITHUB_ISSUES" target="_blank" rel="noopener">issues GitHub</a>.
          </p>

          <h3>Hébergement</h3>
          <p>
            Le site est hébergé par {{ HOST.name }}, {{ HOST.form }}, {{ HOST.address }}. {{ HOST.rcs }}. TVA :
            {{ HOST.tva }}. Tél. {{ HOST.phone }}. <a :href="HOST.site" target="_blank" rel="noopener">ovhcloud.com</a>.
          </p>
          <p>
            Les illustrations de cartes et bannières sont servies par le CDN de Riot Games, Inc., sans copie ni
            redistribution locale. Les polices d'écriture sont hébergées sur le même serveur que le site.
          </p>

          <h3>Propriété intellectuelle — Riot Games</h3>
          <p class="legal-quote">{{ RIOT_DISCLAIMER_EN }}</p>
          <p>{{ RIOT_DISCLAIMER_FR }}</p>
          <p class="legal-quote">{{ RIOT_GENERAL_DISCLAIMER_EN }}</p>
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

          <h3>Code source</h3>
          <p>
            Le code de Riftarium est consultable sur GitHub sous licence « source accessible » : lecture et
            contributions, pas de copie ni de redéploiement sans autorisation. Cette licence ne couvre aucun actif Riot.
          </p>
        </template>

        <template v-else-if="page === 'privacy'">
          <h3>Responsable de traitement</h3>
          <p>
            L'éditeur de Riftarium (voir
            <RouterLink to="/mentions-legales">mentions légales</RouterLink>) est responsable des traitements décrits
            ici.
          </p>

          <h3>Données traitées</h3>
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
              <strong>Communauté</strong> : likes, compteur de vues uniques. Pour un visiteur non connecté, un hash
              SHA-256 tronqué de l'adresse IP est stocké afin de ne compter qu'une visite par personne et par deck. Ce
              hash n'est pas reversé en adresse IP dans l'interface.
            </li>
            <li>
              <strong>Session</strong> : un cookie HTTP-only <code>riftarium_session</code> (jeton JWT, 24 heures,
              renouvelé à la connexion). Le navigateur ne peut pas le lire en JavaScript.
            </li>
          </ul>

          <h3>Finalités et bases</h3>
          <ul>
            <li>Fournir le compte, la collection et le deck builder — exécution du service demandé.</li>
            <li>Publier les decks que vous rendez publics — exécution du service / intérêt légitime communautaire.</li>
            <li>Compter les vues uniques — intérêt légitime (statistique d'audience d'un deck, pas de publicité).</li>
            <li>Modérer les textes publiés — intérêt légitime et obligation de limiter les abus.</li>
            <li>Sécurité du compte (mot de passe, jeton) — intérêt légitime.</li>
          </ul>
          <p>Aucune donnée n'est vendue. Aucune publicité, aucun traceur publicitaire, aucun profilage commercial.</p>

          <h3>Durées de conservation</h3>
          <ul>
            <li>
              Compte, collection, decks : jusqu'à suppression du compte par vos soins, ou suppression par l'éditeur.
            </li>
            <li>Jeton de session : 24 heures, ou jusqu'à déconnexion (révocation immédiate du cookie).</li>
            <li>
              Hash d'IP des vues : tant que le deck public existe. Il est effacé avec le deck ou, pour un compte, à la
              suppression de ce compte.
            </li>
          </ul>

          <h3>Destinataires et sous-traitants techniques</h3>
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

          <h3>Vos droits</h3>
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

          <h3>Âge</h3>
          <p>
            Le service n'est pas destiné aux moins de 15 ans (âge du consentement numérique en France). L'inscription
            exige de le confirmer.
          </p>
        </template>

        <template v-else-if="page === 'terms'">
          <h3>Objet</h3>
          <p>
            Riftarium est un compagnon fan-made gratuit pour le jeu de cartes Riftbound : cartothèque, règles,
            collection personnelle, deck builder et partage de decks. C'est un projet en <strong>bêta fermée</strong>,
            indépendant de Riot Games, non annoncé publiquement.
          </p>
          <p class="legal-quote">{{ RIOT_DISCLAIMER_EN }}</p>
          <p>{{ RIOT_DISCLAIMER_FR }}</p>
          <p class="legal-quote">{{ RIOT_GENERAL_DISCLAIMER_EN }}</p>
          <p>{{ RIOT_GENERAL_DISCLAIMER_FR }}</p>

          <h3>Compte</h3>
          <p>
            L'inscription est réservée aux personnes d'au moins 15 ans. Vous êtes responsable de la confidentialité de
            votre mot de passe et des contenus que vous publiez (pseudo, bio, decks, descriptions).
          </p>

          <h3>Formats de decks</h3>
          <ul>
            <li>
              <strong>Mode tournoi</strong> : le site vérifie les règles officielles de construction (légende, champs de
              bataille, runes, taille, exemplaires, domaines, champion élu).
            </li>
            <li>
              <strong>Mode libre</strong> : format <strong>non officiel</strong>. Il n'applique pas les contraintes de
              tournoi. Il ne s'agit pas d'un format Riot.
            </li>
          </ul>

          <h3>Contenus publiés</h3>
          <p>
            En rendant un deck public ou en remplissant une bio, vous autorisez Riftarium à l'afficher aux visiteurs du
            site, uniquement pour le fonctionnement du service. Vous gardez la responsabilité de vos textes. Un filtre
            automatique peut retenir un contenu ; l'éditeur peut le dépublier ou supprimer un compte en cas d'abus.
          </p>
          <p>
            Interdit notamment : insultes, harcèlement, incitation à la haine, spam, arnaques, vente hors cadre,
            usurpation, contenu illégal.
          </p>

          <h3>Données de cartes et de règles</h3>
          <p>
            Les cartes et règles reproduites restent la propriété de Riot Games. En cas d'écart, les documents et
            traductions officiels font foi. Le site n'est pas un client de jeu : aucune partie n'est simulée, aucun
            classement de joueurs, aucun score de victoire.
          </p>

          <h3>Disponibilité</h3>
          <p>
            Le service est fourni « en l'état », sans garantie de disponibilité ni d'exactitude des données pendant la
            bêta. L'éditeur peut modifier, suspendre ou arrêter le site, notamment si Riot le demande.
          </p>

          <h3>Droit applicable</h3>
          <p>Les présentes sont soumises au droit français. Tout litige relève des tribunaux compétents en France.</p>
        </template>

        <template v-else-if="page === 'cookies'">
          <h3>Consentement : ce qui est obligatoire, ce qui ne l'est pas</h3>
          <p>
            La CNIL n'exige un bandeau de consentement que pour les traceurs non nécessaires (publicité, réseaux
            sociaux, mesure d'audience). Riftarium n'en dépose aucun. Un bandeau d'information s'affiche à la première
            visite pour l'expliquer ; il n'y a rien à « accepter » au-delà de cette information.
          </p>

          <h3>Stockage strictement nécessaire</h3>
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

          <h3>Ce qui n'est pas un cookie, mais un traitement</h3>
          <p>
            Les vues de decks publics dédupliquent les visiteurs anonymes via un hash d'adresse IP côté serveur. Voir la
            <RouterLink to="/confidentialite">politique de confidentialité</RouterLink>.
          </p>
          <p>
            Riftarium compte également ses visites de façon agrégée, par jour et par rubrique (accueil, cartes,
            règles…), sans aucune donnée personnelle ni cookie : une empreinte technique salée, non conservée au-delà de
            48 heures, sert uniquement à dédupliquer les visiteurs du jour.
          </p>

          <h3>Tiers au chargement des pages</h3>
          <ul>
            <li>Illustrations : CDN Riot Games. Requête technique d'image, pas un cookie déposé par Riftarium.</li>
            <li>Polices : servies par Riftarium, pas par Google Fonts.</li>
          </ul>
        </template>

        <template v-else>
          <h3>Pourquoi signaler</h3>
          <p>
            Riftarium héberge des textes d'utilisateurs (bios, noms et descriptions de decks). Si un contenu est
            illicite, contraire aux
            <RouterLink to="/cgu">CGU</RouterLink>, ou porte atteinte à un droit, signalez-le.
          </p>

          <h3>Comment faire</h3>
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
            Pour un bug technique sans enjeu légal, une
            <a :href="GITHUB_ISSUES" target="_blank" rel="noopener">issue GitHub</a>
            suffit.
          </p>
        </template>
      </article>
    </div>
  </section>
</template>
