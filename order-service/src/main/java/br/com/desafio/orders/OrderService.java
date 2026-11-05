package br.com.desafio.orders;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.client.ResourceAccessException;

@Service
public class OrderService {

    private final RestClient productClient;

    public OrderService(RestClient.Builder loadBalancedRestClientBuilder) {
        this.productClient = loadBalancedRestClientBuilder
                .baseUrl("http://product-service")
                .build();
    }

    public OrderResponse simulate(OrderRequest request) {
        List<OrderItemResponse> items = request.items().stream()
                .map(this::toOrderItem)
                .toList();
        BigDecimal total = items.stream()
                .map(OrderItemResponse::subtotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return new OrderResponse(UUID.randomUUID(), items, total);
    }

    private OrderItemResponse toOrderItem(OrderItemRequest item) {
        ProductResponse product;
        try {
            product = productClient.get()
                    .uri("/produtos/{id}", item.productId())
                    .retrieve()
                    .body(ProductResponse.class);
        } catch (RestClientResponseException exception) {
            if (exception.getStatusCode() == HttpStatus.NOT_FOUND) {
                throw new ProductNotFoundException(item.productId());
            }
            throw new ProductServiceUnavailableException(exception);
        } catch (ResourceAccessException exception) {
            throw new ProductServiceUnavailableException(exception);
        } catch (IllegalStateException exception) {
            throw new ProductServiceUnavailableException(exception);
        }

        if (product == null) {
            throw new ProductServiceUnavailableException(
                    new IllegalStateException("Resposta vazia do catálogo."));
        }

        BigDecimal subtotal = product.price().multiply(BigDecimal.valueOf(item.quantity()));
        return new OrderItemResponse(
                product.id(), product.name(), item.quantity(), product.price(), subtotal);
    }
}
