# Gestão de pedidos com microserviços

Este projeto demonstra uma forma de dividir uma aplicação em serviços menores que trabalham juntos. O exemplo é um sistema simples de catálogo de produtos e simulação de pedidos, desenvolvido com Java, Spring Boot e Spring Cloud.

Não é necessário conhecer todos esses frameworks para testar o projeto: siga os passos abaixo para iniciar os serviços e fazer suas primeiras requisições.

## O que o sistema faz

- Cadastra produtos com nome, descrição e preço.
- Lista os produtos cadastrados e permite consultar um produto pelo ID.
- Simula um pedido a partir dos IDs dos produtos e das quantidades.
- Calcula o subtotal de cada item e o total do pedido.

O pedido é apenas calculado para a resposta da requisição: ele não é salvo. Os produtos são armazenados em um banco H2 em memória. Por isso, eles são apagados quando o serviço de produtos é encerrado.

## Como os serviços trabalham juntos

Cada aplicação tem uma responsabilidade:

| Serviço | Porta | O que faz |
|---|---:|---|
| `discovery-server` (Eureka) | 8761 | Mantém uma lista dos serviços ativos para que eles possam se encontrar. |
| `product-service` | 8101 | Cadastra e consulta produtos; usa o banco H2. |
| `order-service` | 8201 | Busca os produtos no catálogo e calcula o pedido. |
| `api-gateway` | 8700 | Recebe as requisições e encaminha cada uma ao serviço correto. |

O fluxo de uma simulação é: você envia um pedido ao Gateway; o Gateway encaminha a requisição ao serviço de pedidos; esse serviço consulta o catálogo usando o Eureka; por fim, ele devolve os itens e o total. Assim, para usar as APIs, você só precisa acessar o Gateway na porta `8700`.

## Requisitos para executar

- Java 21 ou superior.
- Maven 3.9 ou superior.
- Windows PowerShell, para usar os scripts deste guia.

Para conferir se Java e Maven estão disponíveis, execute:

```powershell
java -version
mvn -version
```

## Iniciar todos os serviços de uma vez

Abra o PowerShell na pasta do projeto. Se estiver em outra pasta, entre nela com `cd`, por exemplo:

```powershell
cd "C:\caminho\para\MICROSERVICES"
```

Inicie os serviços com:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

O script compila o projeto e inicia os serviços na ordem necessária. Aguarde a mensagem `Tudo pronto. Gateway: http://localhost:8700`. As APIs estarão disponíveis enquanto os serviços estiverem em execução.

O parâmetro `-ExecutionPolicy Bypass` permite executar esse script sem alterar permanentemente a configuração de segurança do PowerShell. Se o PowerShell já permitir a execução de scripts, `.\start.ps1` também funciona.

Para encerrar os serviços:

```powershell
powershell -ExecutionPolicy Bypass -File .\stop.ps1
```

Os registros de execução ficam na pasta `run\logs`. Não inicie uma segunda cópia dos serviços enquanto a primeira ainda estiver ativa: as portas já estarão ocupadas. Se o script avisar que uma porta está em uso, verifique se os serviços já foram iniciados e encerre a execução anterior antes de tentar novamente.

### Verificar se está funcionando

Abra no navegador:

- `http://localhost:8761` — painel do Eureka, onde aparecem os serviços registrados.
- `http://localhost:8700/produtos` — lista de produtos em formato JSON.

É normal que `http://localhost:8700/` não tenha uma página inicial: o Gateway foi configurado para encaminhar as rotas da API, não para mostrar um site.

## Usar a API de produtos

Uma API recebe uma requisição e devolve uma resposta. Para consultar dados, normalmente usamos `GET`; para enviar dados novos, usamos `POST`.

### Listar produtos

Abra `http://localhost:8700/produtos` no navegador ou execute no PowerShell:

```powershell
Invoke-RestMethod -Method Get -Uri "http://localhost:8700/produtos"
```

A resposta é uma lista JSON. Se o catálogo estiver vazio, o resultado será `[]`.

### Cadastrar um produto

No PowerShell, execute:

```powershell
$produto = Invoke-RestMethod -Method Post `
  -Uri "http://localhost:8700/produtos" `
  -ContentType "application/json" `
  -Body '{"name":"Teclado","description":"Teclado mecanico","price":249.90}'

$produto | ConvertTo-Json
```

A resposta inclui o ID gerado para o produto, por exemplo:

```json
{
  "id": 1,
  "name": "Teclado",
  "description": "Teclado mecanico",
  "price": 249.90
}
```

O ID pode ser diferente no seu ambiente. Use o ID recebido na resposta para consultar o produto ou incluí-lo em um pedido:

```powershell
Invoke-RestMethod -Method Get -Uri "http://localhost:8700/produtos/1"
```

Troque `1` pelo ID que foi retornado ao cadastrar o produto.

## Simular um pedido

Pedidos precisam ser enviados com o método `POST` e um corpo JSON contendo uma lista `items`. Cada item informa o ID de um produto já cadastrado (`productId`) e a quantidade (`quantity`).

Este exemplo usa a variável `$produto` criada no passo anterior, portanto não é necessário adivinhar o ID:

```powershell
$pedidoJson = @{
  items = @(
    @{
      productId = $produto.id
      quantity = 2
    }
  )
} | ConvertTo-Json -Depth 4

$pedido = Invoke-RestMethod -Method Post `
  -Uri "http://localhost:8700/pedidos" `
  -ContentType "application/json" `
  -Body $pedidoJson

$pedido | ConvertTo-Json -Depth 5
```

A resposta mostra o identificador do pedido, os produtos encontrados no catálogo e os valores calculados. Para um teclado de `249.90` com quantidade `2`, o total será `499.80`.

Se você já sabe o ID do produto, também pode enviar a requisição diretamente:

```powershell
Invoke-RestMethod -Method Post `
  -Uri "http://localhost:8700/pedidos" `
  -ContentType "application/json" `
  -Body '{"items":[{"productId":1,"quantity":2}]}' |
  ConvertTo-Json -Depth 5
```

Substitua `1` pelo ID existente no catálogo.

### Por que `/pedidos` mostra erro no navegador?

Ao abrir um endereço no navegador, ele faz uma requisição `GET`. A rota `/pedidos`, porém, aceita `POST` porque precisa receber os itens do pedido. Por isso, abrir `http://localhost:8700/pedidos` diretamente pode mostrar `405 Method Not Allowed` — isso não significa que o serviço falhou. Use um dos comandos PowerShell acima para enviar o pedido.

Como o pedido é simulado e não persistido, não existe uma tela ou rota `GET` para consultar pedidos anteriores. O resultado aparece na resposta do `POST`.

## Erros comuns

| Situação | O que significa / como resolver |
|---|---|
| `Port ... is already in use` | Já existe um processo usando essa porta, geralmente uma execução anterior do projeto. Encerre os serviços anteriores antes de iniciar novamente. |
| `404 Not Found` em `/` | Não há página inicial configurada. Use `/produtos` ou `/pedidos`. |
| `405 Method Not Allowed` em `/pedidos` no navegador | O navegador enviou `GET`; simular um pedido exige `POST` com um corpo JSON. |
| Pedido retorna produto não encontrado | Confira se o produto foi cadastrado e se o `productId` enviado corresponde ao ID retornado pelo catálogo. |
| Produtos desapareceram após reiniciar | O H2 deste projeto é em memória e não mantém dados depois que o serviço de produtos é encerrado. |

## Executar manualmente

Se preferir não usar `start.ps1`, compile o projeto na pasta raiz:

```powershell
mvn clean package
```

Depois, abra um terminal para cada comando e execute-os na ordem indicada:

```powershell
mvn -pl discovery-server spring-boot:run
mvn -pl product-service spring-boot:run
mvn -pl order-service spring-boot:run
mvn -pl api-gateway spring-boot:run
```

Para parar cada serviço iniciado dessa forma, use `Ctrl+C` no terminal correspondente.
