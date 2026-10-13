package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.OffsetDateTime;

@Entity
@Table(name = "service_requests", schema = "autoservice")
public class ServiceRequest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "client_id", nullable = false)
    private User client;

    @ManyToOne(optional = false)
    @JoinColumn(name = "vehicle_id", nullable = false)
    private Vehicle vehicle;

    @ManyToOne(optional = false)
    @JoinColumn(name = "service_type_id", nullable = false)
    private ServiceType serviceType;

    @ManyToOne(optional = false)
    @JoinColumn(name = "location_id", nullable = false)
    private ServiceLocation location;

    @ManyToOne
    @JoinColumn(name = "mechanic_id")
    private User mechanic;

    @ManyToOne(optional = false)
    @JoinColumn(name = "status_id", nullable = false)
    private RequestStatus status;

    @Column(nullable = false, columnDefinition = "text")
    private String description;

    @Column(name = "desired_date", nullable = false)
    private LocalDate desiredDate;

    @Column(name = "agreed_date")
    private LocalDate agreedDate;

    @Column(name = "purchase_approval_mode", nullable = false, length = 40)
    private String purchaseApprovalMode;

    @Column(name = "cancel_reason", columnDefinition = "text")
    private String cancelReason;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @Column(name = "completed_at")
    private OffsetDateTime completedAt;
}
