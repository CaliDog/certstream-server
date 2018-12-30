<template>
  <div id="app">
    <frontpage></frontpage>
  </div>
</template>

<script>
import Frontpage from './Frontpage.vue'

export default {
  name: 'app',
  data () {
    return {
    }
  },
  components: {
      Frontpage
  }
}
</script>

<style lang="scss">
  h1, h2, h3, h4, h5, p {
    font-family: 'Open Sans', sans-serif;
  }
  .container{
    max-width: none;
    width: auto;
  }
</style>
