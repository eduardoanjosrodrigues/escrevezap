import "@hotwired/turbo-rails"
import "./analytics"
import { Application } from "@hotwired/stimulus"
import AudioRecorderController from "./controllers/audio_recorder_controller"
import ConnectController       from "./controllers/connect_controller"
import HeroVideoController     from "./controllers/hero_video_controller"
import ContactPickerController from "./controllers/contact_picker_controller"
import LoadableController      from "./controllers/loadable_controller"
import ModalController         from "./controllers/modal_controller"
import OnboardingConnectController from "./controllers/onboarding_connect_controller"
import ProfileController       from "./controllers/profile_controller"
import ToastController         from "./controllers/toast_controller"
import WhatsappDemoController  from "./controllers/whatsapp_demo_controller"

const Stimulus = Application.start()

Stimulus.register("audio-recorder", AudioRecorderController)
Stimulus.register("connect",        ConnectController)
Stimulus.register("hero-video",     HeroVideoController)
Stimulus.register("contact-picker", ContactPickerController)
Stimulus.register("loadable",       LoadableController)
Stimulus.register("modal",          ModalController)
Stimulus.register("onboarding-connect", OnboardingConnectController)
Stimulus.register("profile",        ProfileController)
Stimulus.register("toast",          ToastController)
Stimulus.register("whatsapp-demo",  WhatsappDemoController)
