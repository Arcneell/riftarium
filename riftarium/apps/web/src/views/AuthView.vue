<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { api, setSession } from "../api.js";

const route = useRoute();
const router = useRouter();

const mode = ref("login");
const handle = ref("");
const email = ref("");
const password = ref("");
const error = ref("");

async function submit() {
  error.value = "";
  try {
    const result = mode.value === "login"
      ? await api("/api/auth/login", { method: "POST", body: { email: email.value, password: password.value } })
      : await api("/api/auth/register", { method: "POST", body: { handle: handle.value, email: email.value, password: password.value } });
    setSession(result.token, result.handle);
    router.push(route.query.suite || "/");
  } catch (e) {
    error.value = e.message;
  }
}
</script>

<template>
  <section>
    <div class="wrap" style="max-width:460px">
      <p class="eyebrow">Compte</p>
      <h2>{{ mode === "login" ? "Connexion" : "Inscription" }}</h2>

      <div class="filters" style="margin:16px 0 22px">
        <button class="filter" :aria-pressed="mode === 'login'" @click="mode = 'login'">Connexion</button>
        <button class="filter" :aria-pressed="mode === 'register'" @click="mode = 'register'">Inscription</button>
      </div>

      <form class="panel" @submit.prevent="submit">
        <div class="field" v-if="mode === 'register'">
          <label for="handle">Pseudo (3–32 caractères, lettres/chiffres/-/_)</label>
          <input id="handle" type="text" v-model="handle" autocomplete="username" required minlength="3" maxlength="32" />
        </div>
        <div class="field">
          <label for="email">Email</label>
          <input id="email" type="email" v-model="email" autocomplete="email" required />
        </div>
        <div class="field">
          <label for="password">Mot de passe (8 caractères minimum)</label>
          <input id="password" type="password" v-model="password" :autocomplete="mode === 'login' ? 'current-password' : 'new-password'" required minlength="8" />
        </div>
        <button class="btn btn-gold" type="submit">{{ mode === "login" ? "Se connecter" : "Créer mon compte" }}</button>
        <p v-if="error" class="error">{{ error }}</p>
      </form>
    </div>
  </section>
</template>
