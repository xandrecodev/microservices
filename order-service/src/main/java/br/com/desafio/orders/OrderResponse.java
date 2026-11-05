package br.com.desafio.orders;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record OrderResponse(
        UUID orderId,
        List<OrderItemResponse> items,
        BigDecimal total) {
}
