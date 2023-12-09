<template>
  <div id="app">
    <Frontpage></Frontpage>
  </div>
</template>

<script>
import { defineComponent } from "vue"

import Frontpage from "@/components/Frontpage.vue"

export default defineComponent({
  name: "App",
  components: {
    Frontpage
  }
})
</script>

<style lang="scss" type="text/scss">
h1,
h2,
h3,
h4,
h5,
p {
  font-family: "Open Sans", sans-serif;
}
.container {
  max-width: none;
  width: auto;
}
</style>
