<!-- casino-dapp.vue -->
<template lang="html">
  <div>
    <casino-component/>
    <hello-metamask/>
  </div>
</template>

<script>
  import HelloMetamask from './hello-metamask.vue'
  import CasinoComponent from './casino-component.vue'
  export default {
    name: 'casino-dapp',
    beforeCreate () {
      console.log('registerWeb3 Action dispatched from casino-dapp.vue')
      this.$store.dispatch('registerWeb3')
    },
    components: {
      HelloMetamask,
      CasinoComponent
    }
  }
</script>

<style>
</style>
