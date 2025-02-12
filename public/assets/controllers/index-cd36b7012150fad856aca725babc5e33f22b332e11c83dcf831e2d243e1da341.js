import { application } from "../main"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

// Automatically load all controllers defined in the controllers folder
eagerLoadControllersFrom("controllers", application);
