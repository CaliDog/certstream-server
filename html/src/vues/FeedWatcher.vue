<template>
  <section id="demo" class="section demo-panel">
    <div class="columns call-to-action">
      <div class="column">
        <p>TRY IT!</p>
      </div>
    </div>
    <div class="columns connect-button">
      <div class="column">
        <template v-if="state == states.STATE_DISCONNECTED">
          <a class="button" @click="connectWebsockets">
            OPEN THE FIRE HOSE
          </a>
        </template>
        <template v-else-if="state == states.STATE_CONNECTING">
          <a class="button connecting">
            CONNECTING...
          </a>
        </template>
        <template v-else-if="state == states.STATE_CONNECTED">
          <a class="button connected" @click="connectWebsockets">
            CONNECTED. CLICK TO DISCONNECT <p class="heart-icon"><i v-tooltip.top-center="{content: 'Beats when a heartbeat is received'}" class="fa fa-heart" aria-hidden="true"></i>️</p>
          </a>
        </template>
        <template v-else-if="state == states.STATE_ERROR">
          <a class="button error" @click="connectWebsockets">
            ERROR CONNECTING! CLICK TO TRY AGAIN.
          </a>
        </template>
      </div>
    </div>
    <transition name="slide-toggle">
      <div v-if="state != states.STATE_DISCONNECTED" :class="{fullscreen: fullscreenMessageViewer}" class="columns message-holder">
        <template v-if="messages.length == 0">
          <div class="column holder-column">
              <p class="empty-holder">
                Waiting on certificates...<span class="wave">🌊</span>
              </p>
          </div>
        </template>
        <template v-else>
          <div @click="toggleFullscreen" class="full-screen-button">
            <i v-if="!fullscreenMessageViewer" class="fa fa-expand" aria-hidden="true"></i>
            <i class="fa fa-compress" aria-hidden="true" v-else></i>
          </div>
          <div class="column incoming-list">
            <transition-group
                    name="custom-classes-transition"
                    enter-active-class="animated fadeIn"
            >
              <div v-bind:key="message.data.seen" v-for="message in messages">
                <p
                   v-on:mouseover="toggleActiveMessage(message)"
                   :class="{active: message.active}"
                   class="line"
                >
                  [{{message.data.cert_index }}] {{ message.data.source.url }} - {{ message.data.leaf_cert.subject.CN }}
                </p>
              </div>
            </transition-group>
          </div>
          <div class="column raw-content">
            <pre>{{ activeMessageContent }}</pre>
          </div>
        </template>
      </div>
    </transition>
  </section>

</template>

<script>
    import Vue from 'vue'
    import VTooltip from 'v-tooltip'
    import VueScrollTo from 'vue-scrollto'

    import anime from 'animejs'
    import axios from 'axios'    
    import debounce from 'debounce'

    import RobustWebSocket from 'robust-websocket'

    Vue.use(VTooltip);
    Vue.use(VueScrollTo);

    let states = {
        STATE_DISCONNECTED: "DISCONNECTED",
        STATE_CONNECTING: "CONNECTING",
        STATE_CONNECTED: "CONNECTED",
        STATE_ERROR: "ERROR"
    };

    export default {
        name: 'feedwatcher',
        data () {
            return {
                messages: [],
                latest: [],
                state: "DISCONNECTED",
                states: states,
                activeMessage: null,
                fullscreenMessageViewer: false,
                timerActive: false,
                ws: null
            }
        },
        created () {
            let vm = this;
            axios.get("/latest.json")
                .then(function(response){
                    vm.latest = response.data
                })
        },
        methods: {
            beat () {
                anime({
                    targets: '.heart-icon',
                    scale: [
                        {value: 1.25, duration: 250},
                        {value: 1, duration: 250}
                    ],
                    color: [
                        {value: "#e74c3c", duration: 250},
                        {value: "#ECF0F1", duration: 250}
                    ],
                    elasticity: 500,
                    easing: 'linear'
                });
            },
            connectWebsockets () {
                let vm = this;

                if (this.state === states.STATE_CONNECTED) {
                    this.timerActive = false;
                    this.state = states.STATE_DISCONNECTED;
                    console.log("Disconnecting from certstream...");
                    this.ws.close();
                    this.messages = [];
                    return
                }

                this.state = states.STATE_CONNECTING;

                console.log("Connecting to certstream...");

                if(location.protocol === 'https:'){
                    this.ws = new RobustWebSocket("wss://" + location.host + "/");
                } else {
                    this.ws = new RobustWebSocket("ws://" + location.host + "/");
                }

                this.ws.debug = true;

                this.ws.addEventListener('open', () => {
                    console.log("onopen called...");
                    this.state = states.STATE_CONNECTED
                });

                this.ws.addEventListener('error', () => {
                    console.log("onerror called...");
                    this.state = states.STATE_ERROR
                });

                this.ws.addEventListener('message', debounce((message) => {
                    console.log("onmessage called...", message);
                    let parsedMessage = JSON.parse(message.data);

                    if (parsedMessage.message_type === "heartbeat") {
                        this.beat()
                    } else {
                        this.timerActive = false;
                        this.messages.unshift(parsedMessage);
                        if (this.messages.length > 1000) {
                            this.messages.pop();
                        }
                    }
                }, 100));

                function seedMessages(){
                    let message = vm.latest.messages.shift();
                    if (!message || !vm.timerActive){
                        return
                    }
                    vm.messages.unshift(message);
                    setTimeout(seedMessages, Math.random() * (1500 - 500) + 500)
                }

                this.timerActive = true;
                setTimeout(seedMessages, 2500);
            },
            toggleActiveMessage (message) {
                if (this.activeMessage){
                    this.activeMessage.active = false
                }
                message.active = true;
                this.activeMessage = message;
            },
            toggleFullscreen () {
                this.fullscreenMessageViewer = !this.fullscreenMessageViewer;
                if (this.fullscreenMessageViewer){
                    this.$scrollTo(".message-holder", 500);
                }
                document.documentElement.classList.toggle('scroll-disabled')
            }
        },
        computed: {
            activeMessageContent: function() {
              if (!this.activeMessage){
                  return "Hover over a message on  the left!"
              }
              return JSON.stringify(this.activeMessage, null, 2);
            }
        }
    }
</script>

<style lang="scss">
  html.scroll-disabled{
    overflow: hidden;
  }
  .line {
    color: #ECF0F1;
    border: 1px solid transparent;
    transition: all .15s;
    padding: 0 4px;
    cursor: default;
    &.active{
      border: 1px solid white;
    }
  }

  .connect-button {
    a.button {
      transition: all 1s, box-shadow .2s, top .2s, background .25s;
      box-shadow: 0 4px hsla(206, 67%, 35%, 1);
      border: none !important;
      top: 0;
      &:hover {
        top: 2px;
        box-shadow: 0 2px hsla(206, 67%, 35%, 1);
      }
      &:active{
        top: 4px;
        box-shadow: 0 0 hsla(206, 67%, 35%, 1);
      }
      &.connecting{
        background: rgba(26,175,93,0.50);
        box-shadow: 0 4px hsla(128, 37%, 35%, 0.50);
        &:hover{
          box-shadow: 0 2px hsla(128, 37%, 35%, 0.50);
        }
        &:active{
          box-shadow: 0 0 hsla(128, 37%, 35%, 0.50);
        }
      }
      &.connected{
        background: #1AAF5D;
        box-shadow: 0 4px hsla(128, 37%, 35%, 1);
        &:hover{
          box-shadow: 0 2px hsla(128, 37%, 35%, 1);
        }
        &:active{
          box-shadow: 0 0 hsla(128, 37%, 35%, 1);
        }
      }
      &.error{
        background: #e74c3c;
      }
    }
    .heart-icon {
      padding-left: 10px;
      i {
        padding-top: 2px;
      }
    }
  }

  .message-holder {
    height: 75vh;
    transition: height .5s, width .5s;
    width: calc(100vw - 200px);
    margin-bottom: 50px !important;
    background: #2E3032;
    overflow: hidden;
    position: relative;
    &.fullscreen{
      width: 100vw;
      height: 100vh;
      .full-screen-button:hover{
        i{
          font-size: 16px;
        }
      }
    }

    .full-screen-button{
      height: 50px;
      width: 50px;
      top: 0;
      right: 0;
      position: absolute;
      cursor: pointer;
      display: flex;
      justify-content: center;
      align-items: center;
      i{
        font-size: 21px;
        transition: all .25s;
      }
      &:hover{
        i{
          font-size: 26px;
        }
      }
    }

    .incoming-list {
      overflow: scroll;
    }

    .raw-content{
      width: 50%;
      overflow: scroll;
      background: whitesmoke;
    }

    &.slide-toggle-enter, &.slide-toggle-leave-active {
      height: 0;
      p.empty-holder{
        opacity: 0;
        transition: opacity 1.5s;
      }
    }

    .holder-column {
      display: flex;
      justify-content: center;
      align-items: center;

      .empty-holder {
        font-size: 24px;
        font-weight: 700;
        color: #ecf0f1;
        opacity: 1;
        transition: opacity 2.5s;

        .wave {
          font-size: 30px;
          margin-right: 10px;
        }
      }
    }
  }


  .tooltip {
    display: block !important;
    z-index: 10000;
    font-family: 'Open Sans', sans-serif;
    .tooltip-inner {
      background: #333;
      color: white;
      border-radius: 16px;
      padding: 7px 12px;
    }

    .tooltip-arrow {
      width: 0;
      height: 0;
      border-style: solid;
      position: absolute;
      margin: 5px;
      border-color: #333;
    }

    &[x-placement^="top"] {
      margin-bottom: 5px;

      .tooltip-arrow {
        border-width: 5px 5px 0 5px;
        border-left-color: transparent !important;
        border-right-color: transparent !important;
        border-bottom-color: transparent !important;
        bottom: -5px;
        left: calc(50% - 5px);
        margin-top: 0;
        margin-bottom: 0;
      }
    }

    &[x-placement^="bottom"] {
      margin-top: 5px;

      .tooltip-arrow {
        border-width: 0 5px 5px 5px;
        border-left-color: transparent !important;
        border-right-color: transparent !important;
        border-top-color: transparent !important;
        top: -5px;
        left: calc(50% - 5px);
        margin-top: 0;
        margin-bottom: 0;
      }
    }

    &[x-placement^="right"] {
      margin-left: 5px;

      .tooltip-arrow {
        border-width: 5px 5px 5px 0;
        border-left-color: transparent !important;
        border-top-color: transparent !important;
        border-bottom-color: transparent !important;
        left: -5px;
        top: calc(50% - 5px);
        margin-left: 0;
        margin-right: 0;
      }
    }

    &[x-placement^="left"] {
      margin-right: 5px;

      .tooltip-arrow {
        border-width: 5px 0 5px 5px;
        border-top-color: transparent !important;
        border-right-color: transparent !important;
        border-bottom-color: transparent !important;
        right: -5px;
        top: calc(50% - 5px);
        margin-left: 0;
        margin-right: 0;
      }
    }

    &[aria-hidden='true'] {
      visibility: hidden;
      opacity: 0;
      transition: opacity .15s, visibility .15s;
    }

    &[aria-hidden='false'] {
      visibility: visible;
      opacity: 1;
      transition: opacity .15s;
    }
  }
</style>
