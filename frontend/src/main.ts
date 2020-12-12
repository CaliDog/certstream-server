import "animate.css/animate.css";
import "bulma/css/bulma.css";

import VTooltip from "v-tooltip";
import { createApp } from "vue";

import App from "./App.vue";

const app = createApp(App);
app.use(VTooltip);
app.mount("#app");
