import Vue from 'vue'
import App from './vues/App.vue'

require('./main.scss');

window.component = new Vue({
  el: '#app',
  render: h => h(App)
});
