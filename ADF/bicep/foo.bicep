param foo2 string = 'hello'
param foo3 string = 'world'

var foo = foo2

output myfoo string = foo


resource webapp 'Microsoft.Web/sites@2021-01-01' existing = {
  name: 'ACU1-BRW-AOA-T5-wsWPS01'
}

output webapp object = webapp.properties.siteConfig
