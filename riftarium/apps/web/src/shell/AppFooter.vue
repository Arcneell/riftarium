<script setup>
import {
  CLOSED_BETA,
  CONTACT_EMAIL,
  CONTACT_MAILTO,
  GITHUB_ISSUES,
  GITHUB_REPO,
  LEGAL_NAV,
  RIOT_DISCLAIMER_EN,
  RIOT_GENERAL_DISCLAIMER_EN,
  SHOW_DONATIONS
} from "../legal.js"

/* Bande sobre en bas du contenu : la navigation vit dans le rail, pas ici.
   Les avertissements Riot restent en anglais, la seule version que la politique
   « Legal Jibber Jabber » impose de reproduire. */
</script>

<template>
  <footer class="footer">
    <div class="footer-row">
      <nav class="footer-links" aria-label="Liens du site">
        <RouterLink v-for="item in LEGAL_NAV" :key="item.key" :to="item.path">{{ item.label }}</RouterLink>
        <a :href="GITHUB_REPO" target="_blank" rel="noopener">Code source</a>
        <a :href="GITHUB_ISSUES" target="_blank" rel="noopener">Signaler un bug</a>
        <!-- Toujours la dernière release : l'asset garde le nom fixe riftarium.apk. -->
        <a
          href="https://github.com/Arcneell/riftarium/releases/latest/download/riftarium.apk"
          title="Version de test signée hors Play Store : autoriser l'installation de sources inconnues."
          >Application Android</a
        >
        <a v-if="SHOW_DONATIONS" href="https://ko-fi.com/arcneell" target="_blank" rel="noopener">Soutenir</a>
      </nav>
      <p class="footer-contact">
        <a :href="CONTACT_MAILTO">{{ CONTACT_EMAIL }}</a>
        <span v-if="CLOSED_BETA"> · bêta fermée, accès sur invitation</span>
      </p>
    </div>
    <div class="footer-legal">
      <p>{{ RIOT_GENERAL_DISCLAIMER_EN }}</p>
      <p>{{ RIOT_DISCLAIMER_EN }}</p>
      <p>
        Visuels et textes officiels © Riot Games, Inc., servis depuis le CDN de Riot. Détail sur les
        <RouterLink to="/mentions-legales">mentions légales</RouterLink>.
      </p>
    </div>
  </footer>
</template>

<style scoped>
.footer {
  margin-top: var(--space-7);
  padding: var(--space-5);
  border-top: 1px solid var(--line);
  font-size: 13px;
  color: var(--ink-muted);
}
.footer-row {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: var(--space-3) var(--space-5);
}
.footer-links {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2) var(--space-4);
  font-family: var(--font-label);
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.footer-links a {
  color: var(--ink-muted);
}
.footer-links a:hover {
  color: var(--ink);
}
.footer-legal {
  display: grid;
  gap: var(--space-2);
  margin-top: var(--space-4);
  font-size: 12px;
  line-height: 1.5;
}
</style>
