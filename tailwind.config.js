module.exports = {
  content: [
    './app/views/**/*.{erb,haml,html,slim}',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        'brand': {
          light: '#9DD9D2',    // Light blue
          primary: '#00A5A8',  // Teal
          dark: '#012E40',     // Dark blue
          accent: '#F7B32B',   // Yellow
          warm: '#FF8811'      // Orange
        }
      },
      fontFamily: {
        sans: ['Roboto', 'Verdana', 'sans-serif'],
      },
      backgroundImage: {
        'nav-gradient': 'linear-gradient(to right, var(--tw-gradient-from), var(--tw-gradient-to))',
      },
    },
  },
  plugins: [],
}