// Import and register all your controllers from the importmap under controllers/*

import { application } from "./application"

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export { application }
