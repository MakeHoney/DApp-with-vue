<!-- casino-dapp.vue -->
<template lang="html">
  <hello-metamask/>
</template>

<script>
  import HelloMetamask from './hello-metamask.vue'
  export default {
    name: 'casino-dapp',
    beforeCreate () {
      console.log('registerWeb3 Action dispatched from casino-dapp.vue')
      this.$store.dispatch('registerWeb3')
    },
    components: { HelloMetamask }
  }
</script>

<style>
</style>
