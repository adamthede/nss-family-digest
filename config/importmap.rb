# Pin npm packages by running ./bin/importmap

# Pin core libraries
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

# Pin Chartkick and Chart.js
pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"

# Pin Ahoy
pin "ahoy.js", to: "ahoy.js"

# Pin Trix and ActionText
pin "trix"
pin "@rails/actiontext", to: "actiontext.js"

# Pin your main.js
pin "main", to: "main.js", preload: true

# Pin controllers
pin_all_from "app/javascript/controllers", under: "controllers"
