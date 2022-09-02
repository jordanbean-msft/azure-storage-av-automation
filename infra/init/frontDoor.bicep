param frontDoorName string
param location string

resource frontDoor 'Microsoft.Network/frontDoors@2021-06-01' = {
  name: frontDoorName
  location: location
  properties: {
  }
}

output frontDoorName string = frontDoor.name
