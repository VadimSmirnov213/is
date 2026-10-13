package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "purchase_approvals", schema = "autoservice")
public class PurchaseApproval {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(optional = false)
    @JoinColumn(name = "purchase_request_id", nullable = false, unique = true)
    private PartPurchaseRequest purchaseRequest;

    @ManyToOne
    @JoinColumn(name = "decided_by")
    private User decidedBy;

    @Column(nullable = false, length = 16)
    private String decision;

    @Column(columnDefinition = "text")
    private String comment;

    @Column(name = "decided_at", nullable = false)
    private OffsetDateTime decidedAt;
}
