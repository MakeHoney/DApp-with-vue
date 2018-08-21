<template lang="html">

</template>

<script>
  export default {
    name: 'casino',
    mounted () {
      console.log('dispatching getContractInstance')
      this.$store.dispatch('getContractInstance')
    },
  }
</script>

<style lang="css">
</style>
