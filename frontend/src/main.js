import "@fortawesome/fontawesome-free/css/all.css"
import "@fortawesome/fontawesome-free/js/all.js"
import "animate.css/animate.css"
import "bulma/css/bulma.css"

import "./assets/devicon-colors.css"
import "./assets/devicon.css"

import Vue from "vue"
import App from "./App.vue"

import VTooltip from "v-tooltip"
import VueScrollTo from "vue-scrollto"

Vue.use(VTooltip)
Vue.use(VueScrollTo)

Vue.config.productionTip = false

new Vue({
  render: (h) => h(App)
}).$mount("#app")
