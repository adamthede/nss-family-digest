// This file is auto-generated by ./bin/rails stimulus:manifest:update
// Run that command whenever you add a new controller or create them with
// ./bin/rails generate stimulus controllerName

import { application } from "../main"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

// Eager load all controllers defined in the import map under controllers/**/*_controller
eagerLoadControllersFrom("controllers", application)

// Lazy load controllers as they appear in the DOM (remember not to preload controllers in import map!)
// import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
// lazyLoadControllersFrom("controllers", application)

// Manually register controllers
import DropdownController from "./dropdown_controller"
application.register("dropdown", DropdownController)

import MobileMenuController from "./mobile_menu_controller"
application.register("mobile-menu", MobileMenuController)

import AlertController from "./alert_controller"
application.register("alert", AlertController)

import TagsController from "./tags_controller"
application.register("tags", TagsController);
