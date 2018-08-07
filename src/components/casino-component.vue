<template>
</template>

<script>
export default {
  name: 'casino',
  mounted () {
    console.log('dispatching getContractInstance')
    this.$store.dispatch('getContractInstance')
  },
  data () {
    return {
      amount: null,
      pending: false,
      winEvent: null
    }
  }
}
</script>

<style scoped>

</style>
