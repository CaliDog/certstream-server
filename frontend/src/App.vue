<template>
  <FrontPage></FrontPage>
</template>

<script lang="ts">
import { defineComponent } from "vue";

import FrontPage from "@/components/FrontPage.vue";

export default defineComponent({
  name: "App",
  components: {
    FrontPage,
  },
});
</script>

<style lang="scss">
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

.json-tree.tree-display {
  color: #394359;
  display: flex;
  flex-direction: column;
  font-family: Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
  line-height: 20px;
  .json-tree-root {
    background-color: #f7f8f9;
    border-radius: 3px;
    margin: 2px 0;
    min-width: 560px;
    padding: 10px;
  }
  .json-tree-ending,
  .json-tree-row {
    border-radius: 2px;
    display: flex;
  }
  .json-tree-paired,
  .json-tree-row:hover {
    background-color: #bce2ff;
  }
  .json-tree-expando {
    cursor: pointer;
  }
  .json-tree-sign {
    font-weight: 700;
  }
  .json-tree-collapsed {
    color: gray;
    font-style: italic;
  }
  .json-tree-value {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .json-tree-value-string {
    color: #9aab3a;
  }
  .json-tree-value-boolean {
    color: #ff0080;
  }
  .json-tree-value-number {
    color: #4f7096;
  }
  .json-tree-value-null {
    color: #c7444a;
  }
}
</style>
