package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "request_parts", schema = "autoservice")
public class RequestPart {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "request_id", nullable = false)
    private ServiceRequest request;

    @ManyToOne(optional = false)
    @JoinColumn(name = "part_id", nullable = false)
    private Part part;

    @Column(nullable = false)
    private Integer quantity = 1;

    @Column(name = "unit_price", nullable = false, precision = 12, scale = 2)
    private BigDecimal unitPrice;

    @Column(nullable = false, length = 32)
    private String source;

    @Column(name = "is_installed", nullable = false)
    private boolean installed;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;
}
