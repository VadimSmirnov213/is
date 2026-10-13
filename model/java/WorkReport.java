package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "work_reports", schema = "autoservice")
public class WorkReport {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(optional = false)
    @JoinColumn(name = "request_id", nullable = false, unique = true)
    private ServiceRequest request;

    @ManyToOne(optional = false)
    @JoinColumn(name = "mechanic_id", nullable = false)
    private User mechanic;

    @Column(columnDefinition = "text")
    private String diagnosis;

    @Column(name = "work_description", nullable = false, columnDefinition = "text")
    private String workDescription;

    @Column(name = "result_summary", nullable = false, columnDefinition = "text")
    private String resultSummary;

    @Column(name = "labor_cost", nullable = false, precision = 12, scale = 2)
    private BigDecimal laborCost = BigDecimal.ZERO;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;
}
