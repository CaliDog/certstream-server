import Vue from 'vue'
import Router from 'vue-router'
import Frontpage from '@/components/Frontpage'

Vue.use(Router)

export default new Router({
  mode: 'history',
  routes: [
    {
      path: '/',
      name: 'Frontpage',
      component: Frontpage
    }
  ]
})
