def summarize_notes(notes):
    """Simple local stub to simulate Bedrock summarization outputs."""
    if not notes:
        return {
            'overall_summary': 'No notes available for this claim.',
            'customer_summary': 'No notes available.',
            'adjuster_summary': 'No notes available.',
            'recommended_next_step': 'Gather more information.'
        }

    combined = " ".join([n.get('text', '') for n in notes])
    # Very basic heuristics for demo purposes
    overall = combined[:400] + ("..." if len(combined) > 400 else "")
    customer = combined.split('.')[0] if '.' in combined else combined[:200]
    adjuster = combined[-200:]
    recommended = "Review notes and contact claimant to schedule inspection." if 'damage' in combined.lower() or 'loss' in combined.lower() else "Review and close as appropriate."

    return {
        'overall_summary': overall,
        'customer_summary': customer.strip(),
        'adjuster_summary': adjuster.strip(),
        'recommended_next_step': recommended
    }
