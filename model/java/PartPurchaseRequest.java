package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "part_purchase_requests", schema = "autoservice")
public class PartPurchaseRequest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "request_id", nullable = false)
    private ServiceRequest request;

    @ManyToOne(optional = false)
    @JoinColumn(name = "part_id", nullable = false)
    private Part part;

    @ManyToOne(optional = false)
    @JoinColumn(name = "created_by", nullable = false)
    private User createdBy;

    @Column(nullable = false)
    private Integer quantity = 1;

    @Column(nullable = false, columnDefinition = "text")
    private String reason;

    @Column(name = "estimated_cost", nullable = false, precision = 12, scale = 2)
    private BigDecimal estimatedCost;

    @Column(nullable = false, length = 32)
    private String status = "PENDING";

    @Column(name = "purchased_at")
    private OffsetDateTime purchasedAt;

    @Column(name = "received_at")
    private OffsetDateTime receivedAt;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;
}
