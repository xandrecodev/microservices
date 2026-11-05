package br.com.desafio.orders;

import java.math.BigDecimal;

public record ProductResponse(Long id, String name, String description, BigDecimal price) {
}
