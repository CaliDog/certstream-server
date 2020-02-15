/* eslint-disable import/first */
import Vue from 'vue'
import App from './App'
import router from './router'

import VTooltip from 'v-tooltip'
import VueScrollTo from 'vue-scrollto'

Vue.use(VTooltip)
Vue.use(VueScrollTo)

Vue.config.productionTip = false

/* eslint-disable no-new */
window.vueInstance = new Vue({
  el: '#app',
  router,
  render: h => h(App)
})
